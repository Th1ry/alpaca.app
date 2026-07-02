from __future__ import annotations

import re
import time
from datetime import datetime, timezone
from urllib.parse import urlencode

from app.models.schemas import OptionRow, OptionsChainResponse
from app.services.alpaca_client import get_alpaca
from app.services.trading import get_quote

_exp_cache: dict[str, tuple[float, list[str]]] = {}
_chain_cache: dict[str, tuple[float, OptionsChainResponse]] = {}
EXP_TTL = 1800
CHAIN_TTL = 30

OCC_RE = re.compile(r"^([A-Z]{1,6})(\d{6})([CP])(\d{8})$")


def parse_occ_symbol(occ: str) -> dict | None:
    m = OCC_RE.match(occ.upper().strip())
    if not m:
        return None
    underlying, yymmdd, cp, strike_raw = m.groups()
    strike = round(int(strike_raw) / 1000, 2)
    expiry = f"20{yymmdd[:2]}-{yymmdd[2:4]}-{yymmdd[4:6]}"
    return {
        "underlying": underlying,
        "option_type": "call" if cp == "C" else "put",
        "strike": strike,
        "expiry": expiry,
        "occ": occ.upper(),
    }


def _spot_strike_band(spot: float) -> tuple[float, float]:
    band = max(spot * 0.12, 12.0 if spot > 150 else 6.0)
    return round(max(0.01, spot - band), 2), round(spot + band, 2)


async def _fetch_all_contracts(sym: str, **filters: str) -> list[dict]:
    """Paginate Alpaca options contracts API (limit 1000 per page)."""
    client = get_alpaca()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    base: dict[str, str] = {
        "underlying_symbols": sym,
        "status": "active",
        "expiration_date_gte": today,
        "limit": "1000",
        **filters,
    }
    all_rows: list[dict] = []
    page_token: str | None = None
    while True:
        params = dict(base)
        if page_token:
            params["page_token"] = page_token
        data = await client.trading_request("GET", f"/v2/options/contracts?{urlencode(params)}")
        batch = data.get("option_contracts") if isinstance(data, dict) else data
        if isinstance(batch, list):
            all_rows.extend(batch)
        page_token = data.get("next_page_token") if isinstance(data, dict) else None
        if not page_token:
            break
    return all_rows


def _parse_snapshot_chain(snapshots: dict) -> list[OptionRow]:
    by_strike: dict[float, dict] = {}
    for occ, snap in snapshots.items():
        parsed = parse_occ_symbol(occ)
        if not parsed:
            continue
        strike = parsed["strike"]
        row = by_strike.setdefault(strike, {"strike": strike})
        quote = snap.get("latestQuote") or {}
        trade = snap.get("latestTrade") or {}
        bid = quote.get("bp")
        ask = quote.get("ap")
        last = trade.get("p") or ask or bid
        if parsed["option_type"] == "call":
            row["call_bid"] = float(bid) if bid else None
            row["call_ask"] = float(ask) if ask else None
            row["call_last"] = float(last) if last else None
            row["call_occ"] = occ
        else:
            row["put_bid"] = float(bid) if bid else None
            row["put_ask"] = float(ask) if ask else None
            row["put_last"] = float(last) if last else None
            row["put_occ"] = occ

    return [
        OptionRow(
            strike=r["strike"],
            call_bid=r.get("call_bid"),
            call_ask=r.get("call_ask"),
            call_last=r.get("call_last"),
            call_occ=r.get("call_occ"),
            put_bid=r.get("put_bid"),
            put_ask=r.get("put_ask"),
            put_last=r.get("put_last"),
            put_occ=r.get("put_occ"),
        )
        for r in sorted(by_strike.values(), key=lambda x: x["strike"])
    ]


async def _chain_from_contracts(sym: str, exp: str, spot: float) -> list[OptionRow]:
    low, high = _spot_strike_band(spot)
    contracts = await _fetch_all_contracts(sym, expiration_date=exp)

    by_strike: dict[float, dict] = {}
    for c in contracts:
        strike = float(c.get("strike_price") or 0)
        if not strike or strike < low or strike > high:
            continue
        row = by_strike.setdefault(strike, {"strike": strike})
        occ = c.get("symbol") or ""
        opt_type = (c.get("type") or "").lower()
        if opt_type == "call":
            row["call_occ"] = occ
        elif opt_type == "put":
            row["put_occ"] = occ

    return [
        OptionRow(strike=r["strike"], call_occ=r.get("call_occ"), put_occ=r.get("put_occ"))
        for r in sorted(by_strike.values(), key=lambda x: x["strike"])
    ]


async def get_option_expirations(symbol: str) -> list[str]:
    sym = symbol.upper()
    cached = _exp_cache.get(sym)
    if cached and time.time() - cached[0] < EXP_TTL:
        return cached[1]

    contracts = await _fetch_all_contracts(sym)
    dates: set[str] = set()
    for c in contracts:
        d = c.get("expiration_date")
        if d:
            dates.add(d)
    exps = sorted(dates)
    if exps:
        _exp_cache[sym] = (time.time(), exps)
    return exps


async def get_options_chain(
    symbol: str,
    expiry: str | None = None,
    spot_hint: float | None = None,
) -> OptionsChainResponse:
    sym = symbol.upper()
    cache_key = f"{sym}:{expiry or ''}:{spot_hint or ''}"
    cached = _chain_cache.get(cache_key)
    if cached and time.time() - cached[0] < CHAIN_TTL:
        return cached[1]

    from app.config import get_settings

    settings = get_settings()
    feed = settings.alpaca_data_feed
    option_feed = settings.alpaca_option_feed
    spot = spot_hint or (await get_quote(sym, feed)).price
    exps = await get_option_expirations(sym)
    if not exps:
        return OptionsChainResponse(symbol=sym, expiry="", spot=spot, expirations=[], chain=[])

    exp = expiry if expiry in exps else exps[0]
    strike_lo, strike_hi = _spot_strike_band(spot)

    client = get_alpaca()
    path = (
        f"/v1beta1/options/snapshots/{sym}?feed={option_feed}"
        f"&expiration_date={exp}&strike_price_gte={strike_lo}&strike_price_lte={strike_hi}"
        f"&limit=1000"
    )
    data = await client.data_request("GET", path)
    snapshots = data.get("snapshots") or {}
    chain = _parse_snapshot_chain(snapshots)

    if not chain:
        chain = await _chain_from_contracts(sym, exp, spot)

    result = OptionsChainResponse(
        symbol=sym, expiry=exp, spot=round(spot, 2), expirations=exps, chain=chain
    )
    _chain_cache[cache_key] = (time.time(), result)
    return result


def clear_options_cache(symbol: str | None = None) -> None:
    if symbol:
        sym = symbol.upper()
        _exp_cache.pop(sym, None)
        keys = [k for k in _chain_cache if k.startswith(f"{sym}:")]
        for k in keys:
            _chain_cache.pop(k, None)
    else:
        _exp_cache.clear()
        _chain_cache.clear()
