from __future__ import annotations

import logging
import re
import time
from datetime import date, datetime, timezone
from urllib.parse import quote

from app.services.alpaca_client import AlpacaClient, AlpacaError, get_alpaca

logger = logging.getLogger(__name__)

OCC_RE = re.compile(r"^([A-Z]{1,6})(\d{6})([CP])(\d{8})$")
_SETTLE_COOLDOWN_SEC = 120.0
_last_settle_attempt: dict[str, float] = {}


def option_expiry_date(occ: str) -> date | None:
    m = OCC_RE.match(occ.upper().strip())
    if not m:
        return None
    yymmdd = m.group(2)
    return date.fromisoformat(f"20{yymmdd[:2]}-{yymmdd[2:4]}-{yymmdd[4:6]}")


def is_option_expired(occ: str, now: datetime | None = None) -> bool:
    """True after the expiration calendar day (UTC) or after 20:00 UTC on expiry day."""
    exp = option_expiry_date(occ)
    if exp is None:
        return False
    now = now or datetime.now(timezone.utc)
    if now.date() > exp:
        return True
    if now.date() == exp:
        return now.hour >= 20
    return False


def _option_qty(row: dict) -> float:
    return abs(float(row.get("qty") or 0))


def _option_close_side(row: dict) -> str:
    return "sell" if float(row.get("qty") or 0) > 0 else "buy"


def is_worthless_option_row(row: dict) -> bool:
    """Deep OTM / no-bid options marked at ~$0."""
    sym = str(row.get("symbol") or "").upper()
    if not OCC_RE.match(sym):
        return False
    price = float(row.get("current_price") or 0)
    mv = abs(float(row.get("market_value") or 0))
    return price <= 0.01 and mv <= 1.0


async def _cancel_open_orders(client: AlpacaClient, symbol: str) -> None:
    sym = symbol.upper()
    try:
        rows = await client.trading_request(
            "GET", f"/v2/orders?status=open&symbols={quote(sym, safe='')}"
        )
    except AlpacaError as e:
        logger.warning("cancel open orders list failed for %s: %s", sym, e.message)
        return
    if not isinstance(rows, list):
        return
    for o in rows:
        oid = o.get("id")
        if not oid:
            continue
        try:
            await client.trading_request("DELETE", f"/v2/orders/{oid}")
        except AlpacaError as e:
            logger.warning("cancel order %s for %s failed: %s", oid, sym, e.message)


async def _try_liquidate_position(client: AlpacaClient, symbol: str) -> bool:
    sym = symbol.upper()
    path_sym = quote(sym, safe="")
    try:
        await client.trading_request("DELETE", f"/v2/positions/{path_sym}")
        logger.info("liquidated option position %s via DELETE", sym)
        return True
    except AlpacaError as e:
        logger.info("liquidate %s via DELETE failed (%s): %s", sym, e.status, e.message)
        return False


async def _try_market_close(client: AlpacaClient, row: dict) -> bool:
    sym = str(row.get("symbol") or "").upper()
    qty = _option_qty(row)
    if qty <= 0:
        return False
    qty_str = str(int(qty)) if qty == int(qty) else str(qty)
    body = {
        "symbol": sym,
        "qty": qty_str,
        "side": _option_close_side(row),
        "type": "market",
        "time_in_force": "day",
    }
    try:
        await client.trading_request("POST", "/v2/orders", json=body)
        logger.info("submitted market close for option %s qty=%s", sym, qty_str)
        return True
    except AlpacaError as e:
        logger.info("market close %s failed (%s): %s", sym, e.status, e.message)
        return False


async def _try_penny_limit_close(client: AlpacaClient, row: dict) -> bool:
    sym = str(row.get("symbol") or "").upper()
    qty = _option_qty(row)
    if qty <= 0:
        return False
    qty_str = str(int(qty)) if qty == int(qty) else str(qty)
    body = {
        "symbol": sym,
        "qty": qty_str,
        "side": _option_close_side(row),
        "type": "limit",
        "time_in_force": "day",
        "limit_price": "0.01",
    }
    try:
        await client.trading_request("POST", "/v2/orders", json=body)
        logger.info("submitted $0.01 limit close for illiquid option %s", sym)
        return True
    except AlpacaError as e:
        logger.info("penny limit close %s failed (%s): %s", sym, e.status, e.message)
        return False


async def try_close_illiquid_option(client: AlpacaClient, row: dict) -> str | None:
    """Try DELETE -> $0.01 limit -> market. Return method name or None if all failed."""
    sym = str(row.get("symbol") or "").upper()
    await _cancel_open_orders(client, sym)
    if await _try_liquidate_position(client, sym):
        return "liquidated"
    if await _try_penny_limit_close(client, row):
        return "penny_limit"
    if await _try_market_close(client, row):
        return "market"
    return None


async def _contract_is_expired(client: AlpacaClient, occ: str) -> bool:
    sym = occ.upper()
    if is_option_expired(sym):
        return True
    try:
        data = await client.trading_request("GET", f"/v2/options/contracts/{quote(sym, safe='')}")
    except AlpacaError:
        return is_option_expired(sym)
    if not isinstance(data, dict):
        return is_option_expired(sym)
    status = str(data.get("status") or "").lower()
    if status in {"expired", "inactive", "delisted"}:
        return True
    tradable = data.get("tradable")
    if tradable is False and status != "active":
        return True
    exp_raw = data.get("expiration_date")
    if exp_raw:
        try:
            return date.fromisoformat(str(exp_raw)[:10]) < datetime.now(timezone.utc).date()
        except ValueError:
            pass
    return False


def _should_attempt_settle(occ: str) -> bool:
    now = time.monotonic()
    key = occ.upper()
    last = _last_settle_attempt.get(key, 0.0)
    if now - last < _SETTLE_COOLDOWN_SEC:
        return False
    _last_settle_attempt[key] = now
    return True


async def should_hide_option_row(client: AlpacaClient, row: dict) -> bool:
    sym = str(row.get("symbol") or "").upper()
    if not OCC_RE.match(sym):
        return False
    if is_option_expired(sym):
        return True
    exp = option_expiry_date(sym)
    today = datetime.now(timezone.utc).date()
    if exp is not None and exp <= today:
        return await _contract_is_expired(client, sym)
    return False


async def settle_expired_option_positions(rows: list[dict]) -> list[str]:
    """Try to close expired option positions; return OCC symbols to hide if still ghosting."""
    client = get_alpaca()
    hidden: list[str] = []

    for row in rows if isinstance(rows, list) else []:
        sym = str(row.get("symbol") or "").upper()
        if not OCC_RE.match(sym):
            continue
        if not await should_hide_option_row(client, row):
            continue

        hidden.append(sym)
        if not _should_attempt_settle(sym):
            continue

        result = await try_close_illiquid_option(client, row)
        if not result:
            logger.info("hiding expired unsettled option position %s", sym)

    return hidden


def filter_hidden_option_positions(rows: list[dict], hide_symbols: set[str]) -> list[dict]:
    if not hide_symbols:
        return rows
    out: list[dict] = []
    for row in rows:
        sym = str(row.get("symbol") or "").upper()
        if sym in hide_symbols:
            continue
        out.append(row)
    return out
