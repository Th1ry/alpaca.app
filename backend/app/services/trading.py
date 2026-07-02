from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

from app.models.schemas import AccountSummary, Bar, Order, OrderBookLevel, OrderBookResponse, Position, Quote, SearchResult
from app.services.alpaca_client import AlpacaClient, get_alpaca
from app.services.dismissed_positions import dismiss_symbol, get_dismissed_symbols
from app.services.option_settlement import (
    filter_hidden_option_positions,
    is_worthless_option_row,
    settle_expired_option_positions,
    should_hide_option_row,
    try_close_illiquid_option,
)

TF_MAP = {
    "1m": ("1Min", timedelta(days=2), 500, 1),
    "5m": ("5Min", timedelta(days=5), 400, 1),
    "15m": ("15Min", timedelta(days=7), 320, 1),
    "1h": ("1Hour", timedelta(days=30), 240, 1),
    "4h": ("1Hour", timedelta(days=90), 360, 4),
    "1d": ("1Day", timedelta(days=365), 260, 1),
    # legacy keys
    "1H": ("1Hour", timedelta(days=30), 240, 1),
    "1D": ("1Day", timedelta(days=365), 260, 1),
    "1W": ("1Week", timedelta(days=365 * 3), 160, 1),
}

OCC_RE = re.compile(r"^([A-Z]{1,6})(\d{6})([CP])(\d{8})$")


def _iso_unix(ts: str) -> int:
    t = ts.replace("Z", "+00:00")
    return int(datetime.fromisoformat(t).timestamp())


async def get_account() -> AccountSummary:
    client = get_alpaca()
    a = await client.trading_request("GET", "/v2/account")
    equity = float(a["equity"])
    last = float(a["last_equity"])
    daily = equity - last
    return AccountSummary(
        equity=equity,
        cash=float(a["cash"]),
        buying_power=float(a["buying_power"]),
        daily_pnl=daily,
        daily_pnl_pct=(daily / last * 100) if last else 0.0,
    )


async def _fetch_position_rows() -> list[dict]:
    client = get_alpaca()
    rows = await client.trading_request("GET", "/v2/positions")
    return rows if isinstance(rows, list) else []


def _rows_to_positions(rows: list[dict]) -> list[Position]:
    out: list[Position] = []
    for p in rows:
        qty = abs(float(p["qty"]))
        out.append(
            Position(
                symbol=p["symbol"],
                qty=qty,
                avg_cost=float(p["avg_entry_price"]),
                price=float(p["current_price"]),
                pnl=float(p["unrealized_pl"]),
                pnl_pct=float(p.get("unrealized_plpc") or 0) * 100,
                side="short" if float(p["qty"]) < 0 else "long",
            )
        )
    return out


_ghost_expired: set[str] = set()


def _position_row(rows: list[dict], symbol: str) -> dict | None:
    sym = symbol.upper()
    for row in rows:
        if str(row.get("symbol") or "").upper() == sym:
            return row
    return None


async def get_positions(*, settle_expired: bool = True) -> list[Position]:
    global _ghost_expired
    client = get_alpaca()
    dismissed = get_dismissed_symbols()
    rows = await _fetch_position_rows()
    if settle_expired:
        newly_hidden = await settle_expired_option_positions(rows)
        if newly_hidden:
            _ghost_expired.update(s.upper() for s in newly_hidden)
        rows = await _fetch_position_rows()
        still_on_alpaca = {str(r.get("symbol") or "").upper() for r in rows}
        _ghost_expired &= still_on_alpaca
    hide = _ghost_expired | dismissed
    rows = filter_hidden_option_positions(rows, hide)
    filtered: list[dict] = []
    for row in rows:
        sym = str(row.get("symbol") or "").upper()
        if OCC_RE.match(sym) and await should_hide_option_row(client, row):
            _ghost_expired.add(sym)
            continue
        filtered.append(row)
    return _rows_to_positions(filtered)


async def dismiss_position(symbol: str) -> dict:
    sym = symbol.upper().strip()
    rows = await _fetch_position_rows()
    row = _position_row(rows, sym)
    if row is None:
        raise ValueError(f"no position for {sym}")
    dismiss_symbol(sym)
    global _ghost_expired
    _ghost_expired.add(sym)
    return {"symbol": sym, "dismissed": True}


async def force_settle_expired_options() -> dict:
    global _ghost_expired
    rows = await _fetch_position_rows()
    hidden = await settle_expired_option_positions(rows)
    if hidden:
        _ghost_expired.update(s.upper() for s in hidden)
    remaining = await get_positions(settle_expired=True)
    return {
        "attempted": hidden,
        "remaining": [p.symbol for p in remaining],
    }


async def get_orders(limit: int = 50) -> list[Order]:
    client = get_alpaca()
    rows = await client.trading_request(
        "GET", f"/v2/orders?status=all&limit={limit}&direction=desc"
    )
    out: list[Order] = []
    for o in rows if isinstance(rows, list) else []:
        out.append(
            Order(
                id=o["id"],
                symbol=o["symbol"],
                side=o["side"],
                qty=float(o["qty"]),
                type=o["type"],
                status=o["status"],
                filled_avg_price=float(o["filled_avg_price"]) if o.get("filled_avg_price") else None,
                submitted_at=o.get("submitted_at"),
            )
        )
    return out


async def submit_order(
    symbol: str,
    qty: float,
    side: str,
    order_type: str = "market",
    time_in_force: str = "day",
    limit_price: float | None = None,
    stop_price: float | None = None,
) -> Order:
    client = get_alpaca()
    body: dict = {
        "symbol": symbol.upper(),
        "qty": str(qty),
        "side": side,
        "type": order_type,
        "time_in_force": time_in_force,
    }
    if limit_price is not None:
        body["limit_price"] = str(limit_price)
    if stop_price is not None:
        body["stop_price"] = str(stop_price)
    o = await client.trading_request("POST", "/v2/orders", json=body)
    return Order(
        id=o["id"],
        symbol=o["symbol"],
        side=o["side"],
        qty=float(o["qty"]),
        type=o["type"],
        status=o["status"],
        filled_avg_price=float(o["filled_avg_price"]) if o.get("filled_avg_price") else None,
        submitted_at=o.get("submitted_at"),
    )


def _find_position(positions: list[Position], symbol: str) -> Position | None:
    sym = symbol.upper()
    for p in positions:
        if p.symbol.upper() == sym:
            return p
    return None


def _close_qty(pos: Position, percent: float) -> float:
    pct = max(1.0, min(100.0, percent))
    raw = pos.qty * pct / 100.0
    if OCC_RE.match(pos.symbol.upper()):
        if pct >= 99.9:
            return pos.qty
        return max(1.0, float(int(raw)))
    if pct >= 99.9:
        return pos.qty
    return round(raw, 4)


async def close_position(symbol: str, percent: float = 100.0) -> Order:
    sym = symbol.upper()
    rows = await _fetch_position_rows()
    row = _position_row(rows, sym)
    if row is None:
        raise ValueError(f"no position for {sym}")
    qty = abs(float(row["qty"]))
    pct = max(1.0, min(100.0, percent))
    if pct < 99.9:
        if OCC_RE.match(sym):
            qty = max(1.0, float(int(qty * pct / 100.0)))
        else:
            qty = round(qty * pct / 100.0, 4)
    if qty <= 0:
        raise ValueError("close qty must be positive")
    close_side = "sell" if float(row["qty"]) > 0 else "buy"
    client = get_alpaca()

    if OCC_RE.match(sym) and (is_worthless_option_row(row) or pct >= 99.9):
        partial_row = {**row, "qty": str(qty if close_side == "sell" else -qty)}
        result = await try_close_illiquid_option(client, partial_row)
        if result == "liquidated":
            return Order(
                id="liquidated",
                symbol=sym,
                side=close_side,
                qty=qty,
                type="market",
                status="filled",
                filled_avg_price=0.0,
                submitted_at=datetime.now(timezone.utc).isoformat(),
            )
        if result in {"penny_limit", "market"}:
            orders = await client.trading_request(
                "GET", f"/v2/orders?status=open&symbols={sym}&limit=1&direction=desc"
            )
            if isinstance(orders, list) and orders:
                o = orders[0]
                return Order(
                    id=o["id"],
                    symbol=o["symbol"],
                    side=o["side"],
                    qty=float(o["qty"]),
                    type=o["type"],
                    status=o["status"],
                    filled_avg_price=float(o["filled_avg_price"])
                    if o.get("filled_avg_price")
                    else None,
                    submitted_at=o.get("submitted_at"),
                )
        raise ValueError("no_liquidity")

    return await submit_order(sym, qty, close_side, "market", "day")


async def set_position_bracket(
    symbol: str,
    take_profit_price: float | None = None,
    stop_loss_price: float | None = None,
) -> list[Order]:
    if take_profit_price is None and stop_loss_price is None:
        raise ValueError("take_profit_price or stop_loss_price required")
    positions = await get_positions(settle_expired=False)
    pos = _find_position(positions, symbol)
    if not pos:
        raise ValueError(f"no position for {symbol}")
    close_side = "sell" if pos.side == "long" else "buy"
    qty = pos.qty
    tif = "gtc"
    out: list[Order] = []
    if take_profit_price is not None:
        out.append(
            await submit_order(
                pos.symbol, qty, close_side, "limit", tif, limit_price=take_profit_price
            )
        )
    if stop_loss_price is not None:
        out.append(
            await submit_order(
                pos.symbol, qty, close_side, "stop", tif, stop_price=stop_loss_price
            )
        )
    return out


async def get_quote(symbol: str, feed: str, option_feed: str = "indicative") -> Quote:
    sym = symbol.upper()
    if OCC_RE.match(sym):
        return await _option_quote(sym, option_feed)
    client = get_alpaca()
    snap = await client.data_request("GET", f"/v2/stocks/{sym}/snapshot?feed={feed}")
    return _parse_stock_snapshot(sym, snap)


def _round_price(v: float) -> float:
    return round(v, 4) if 0 < v < 1 else round(v, 2)


def _parse_stock_snapshot(sym: str, snap: dict) -> Quote:
    daily = snap.get("dailyBar") or {}
    prev = snap.get("prevDailyBar") or {}
    trade = snap.get("latestTrade") or {}
    minute = snap.get("minuteBar") or {}
    lq = snap.get("latestQuote") or {}
    bid = float(lq.get("bp") or 0)
    ask = float(lq.get("ap") or 0)
    bid_size = float(lq.get("bs") or 0)
    ask_size = float(lq.get("as") or 0)
    price = float(
        trade.get("p")
        or lq.get("ap")
        or lq.get("bp")
        or minute.get("c")
        or daily.get("c")
        or prev.get("c")
        or 0
    )
    if bid <= 0 and ask <= 0 and price > 0:
        tick = _tick_size(price)
        bid = price - tick
        ask = price + tick
    prev_close = float(prev.get("c") or daily.get("o") or price)
    change = price - prev_close
    return Quote(
        symbol=sym.upper(),
        name=sym.upper(),
        price=_round_price(price),
        change=_round_price(change),
        change_pct=round((change / prev_close * 100) if prev_close else 0, 2),
        prev_close=_round_price(prev_close),
        bid=_round_price(bid),
        ask=_round_price(ask),
        bid_size=round(bid_size, 0),
        ask_size=round(ask_size, 0),
    )


def _parse_option_snapshot(occ: str, snap: dict) -> Quote:
    trade = snap.get("latestTrade") or {}
    lq = snap.get("latestQuote") or {}
    bid = float(lq.get("bp") or 0)
    ask = float(lq.get("ap") or 0)
    bid_size = float(lq.get("bs") or 0)
    ask_size = float(lq.get("as") or 0)
    price = float(trade.get("p") or ask or bid or 0)
    if bid <= 0 and ask <= 0 and price > 0:
        tick = _tick_size(price)
        bid = price - tick
        ask = price + tick
    return Quote(
        symbol=occ.upper(),
        name=occ.upper(),
        price=_round_price(price),
        change=0,
        change_pct=0,
        prev_close=_round_price(price),
        bid=_round_price(bid),
        ask=_round_price(ask),
        bid_size=round(bid_size, 0),
        ask_size=round(ask_size, 0),
    )


async def _option_quote(occ: str, option_feed: str) -> Quote:
    client = get_alpaca()
    data = await client.data_request(
        "GET", f"/v1beta1/options/snapshots?symbols={occ}&feed={option_feed}"
    )
    snapshots = data.get("snapshots") or {}
    snap = snapshots.get(occ) or {}
    return _parse_option_snapshot(occ, snap)


async def get_quotes_batch(
    symbols: list[str], feed: str, option_feed: str
) -> dict[str, Quote]:
    if not symbols:
        return {}
    stocks = [s.upper() for s in symbols if not OCC_RE.match(s.upper())]
    options = [s.upper() for s in symbols if OCC_RE.match(s.upper())]
    out: dict[str, Quote] = {}
    client = get_alpaca()
    if (stocks):
        path = f"/v2/stocks/snapshots?symbols={','.join(stocks)}&feed={feed}"
        data = await client.data_request("GET", path)
        snapshots = data.get("snapshots") or {}
        if not snapshots:
            for key, value in data.items():
                if key in ("snapshots", "next_page_token"):
                    continue
                if isinstance(value, dict) and (
                    "latestTrade" in value
                    or "latestQuote" in value
                    or "dailyBar" in value
                ):
                    snapshots[key] = value
        for sym in stocks:
            snap = snapshots.get(sym)
            if snap:
                out[sym] = _parse_stock_snapshot(sym, snap)
        for sym in stocks:
            if sym not in out:
                try:
                    out[sym] = await get_quote(sym, feed, option_feed)
                except Exception:
                    pass
    for occ in options:
        try:
            out[occ] = await _option_quote(occ, option_feed)
        except Exception:
            pass
    return out


def _tick_size(price: float) -> float:
    if price >= 1000:
        return 1.0
    if price >= 100:
        return 0.1
    if price >= 10:
        return 0.05
    if price >= 1:
        return 0.01
    return 0.01


def _build_order_book_levels(
    best_bid: float,
    best_ask: float,
    bid_size: float,
    ask_size: float,
    levels: int = 5,
) -> tuple[list[OrderBookLevel], list[OrderBookLevel]]:
    if best_bid <= 0 and best_ask <= 0:
        return [], []
    if best_bid <= 0:
        best_bid = best_ask - _tick_size(best_ask)
    if best_ask <= 0:
        best_ask = best_bid + _tick_size(best_bid)

    tick = max((best_ask - best_bid) / 2, _tick_size(best_bid))
    bid_sz = bid_size if bid_size > 0 else 100.0
    ask_sz = ask_size if ask_size > 0 else 100.0

    asks: list[OrderBookLevel] = []
    bids: list[OrderBookLevel] = []
    for i in range(levels):
        asks.append(
            OrderBookLevel(
                price=round(best_ask + i * tick, 2),
                size=round(max(ask_sz * (1 - i * 0.1), 1), 0),
            )
        )
        bids.append(
            OrderBookLevel(
                price=round(best_bid - i * tick, 2),
                size=round(max(bid_sz * (1 - i * 0.1), 1), 0),
            )
        )
    return asks, bids


async def get_order_book(
    symbol: str, feed: str, option_feed: str, levels: int = 5
) -> OrderBookResponse:
    sym = symbol.upper()
    if OCC_RE.match(sym):
        return await _option_order_book(sym, option_feed, levels)
    return await _stock_order_book(sym, feed, levels)


async def _stock_order_book(symbol: str, feed: str, levels: int) -> OrderBookResponse:
    client = get_alpaca()
    snap = await client.data_request("GET", f"/v2/stocks/{symbol}/snapshot?feed={feed}")
    quote = snap.get("latestQuote") or {}
    bid = float(quote.get("bp") or 0)
    ask = float(quote.get("ap") or 0)
    bid_size = float(quote.get("bs") or 0)
    ask_size = float(quote.get("as") or 0)
    if bid <= 0 or ask <= 0:
        trade = snap.get("latestTrade") or {}
        price = float(trade.get("p") or 0)
        if price > 0:
            tick = _tick_size(price)
            bid = price - tick
            ask = price + tick
    asks, bids = _build_order_book_levels(bid, ask, bid_size, ask_size, levels)
    return OrderBookResponse(symbol=symbol, asks=asks, bids=bids)


async def _option_order_book(occ: str, option_feed: str, levels: int) -> OrderBookResponse:
    client = get_alpaca()
    data = await client.data_request(
        "GET", f"/v1beta1/options/snapshots?symbols={occ}&feed={option_feed}"
    )
    snapshots = data.get("snapshots") or {}
    snap = snapshots.get(occ) or {}
    quote = snap.get("latestQuote") or {}
    bid = float(quote.get("bp") or 0)
    ask = float(quote.get("ap") or 0)
    bid_size = float(quote.get("bs") or 0)
    ask_size = float(quote.get("as") or 0)
    if bid <= 0 or ask <= 0:
        trade = snap.get("latestTrade") or {}
        price = float(trade.get("p") or 0)
        if price > 0:
            tick = _tick_size(price)
            bid = price - tick
            ask = price + tick
    asks, bids = _build_order_book_levels(bid, ask, bid_size, ask_size, levels)
    return OrderBookResponse(symbol=occ, asks=asks, bids=bids)


def _resample_bars(bars: list[Bar], factor: int) -> list[Bar]:
    if factor <= 1 or not bars:
        return bars
    out: list[Bar] = []
    for i in range(0, len(bars), factor):
        chunk = bars[i : i + factor]
        if not chunk:
            break
        out.append(
            Bar(
                time=chunk[0].time,
                open=chunk[0].open,
                high=max(b.high for b in chunk),
                low=min(b.low for b in chunk),
                close=chunk[-1].close,
            )
        )
    return out


async def get_bars(
    symbol: str, timeframe: str, feed: str, option_feed: str = "indicative"
) -> list[Bar]:
    client = get_alpaca()
    sym = symbol.upper()
    if OCC_RE.match(sym):
        return await _option_bars(sym, timeframe, option_feed, TF_MAP)
    tf, span, limit, resample = TF_MAP.get(timeframe, TF_MAP["1D"])
    start = (datetime.now(timezone.utc) - span).strftime("%Y-%m-%d")
    path = (
        f"/v2/stocks/bars?symbols={sym}&timeframe={tf}&start={start}"
        f"&limit={limit}&feed={feed}&adjustment=split"
    )
    data = await client.data_request("GET", path)
    raw = (data.get("bars") or {}).get(sym) or []
    bars: list[Bar] = []
    for b in raw:
        o, c = b.get("o"), b.get("c")
        if o is None or c is None:
            continue
        bars.append(
            Bar(
                time=_iso_unix(b.get("t", "")),
                open=round(float(o), 2),
                high=round(float(b.get("h", max(o, c))), 2),
                low=round(float(b.get("l", min(o, c))), 2),
                close=round(float(c), 2),
            )
        )
    return _resample_bars(bars, resample)


async def _option_bars(
    occ: str, timeframe: str, option_feed: str, tf_map: dict
) -> list[Bar]:
    client = get_alpaca()
    tf, span, limit, resample = tf_map.get(timeframe, tf_map["1D"])
    start = (datetime.now(timezone.utc) - span).strftime("%Y-%m-%d")
    path = (
        f"/v1beta1/options/bars?symbols={occ}&timeframe={tf}&start={start}"
        f"&limit={limit}"
    )
    data = await client.data_request("GET", path)
    raw = (data.get("bars") or {}).get(occ) or []
    bars: list[Bar] = []
    for b in raw:
        o, c = b.get("o"), b.get("c")
        if o is None or c is None:
            continue
        bars.append(
            Bar(
                time=_iso_unix(b.get("t", "")),
                open=round(float(o), 4),
                high=round(float(b.get("h", max(o, c))), 4),
                low=round(float(b.get("l", min(o, c))), 4),
                close=round(float(c), 4),
            )
        )
    return _resample_bars(bars, resample)


async def search_symbols(query: str) -> list[SearchResult]:
    client = get_alpaca()
    q = query.strip().upper()
    if not q:
        return []
    try:
        asset = await client.trading_request("GET", f"/v2/assets/{q}")
        if asset.get("tradable"):
            return [SearchResult(symbol=asset["symbol"], name=asset.get("name") or q)]
    except Exception:
        pass
    data = await client.trading_request("GET", "/v2/assets?status=active&asset_class=us_equity")
    out: list[SearchResult] = []
    for a in data if isinstance(data, list) else []:
        sym = a.get("symbol") or ""
        name = a.get("name") or sym
        if q in sym or q in name.upper():
            out.append(SearchResult(symbol=sym, name=name))
            if len(out) >= 12:
                break
    return out
