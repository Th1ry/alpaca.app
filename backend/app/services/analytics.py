from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone

from app.models.schemas import DailyPnl, PnlPoint, PortfolioHistoryResponse, TradeAnalytics
from app.services.alpaca_client import get_alpaca

PERIOD_MAP: dict[str, tuple[str, str]] = {
    "7d": ("1W", "1H"),
    "1m": ("1M", "1D"),
    "1y": ("1A", "1D"),
}


async def get_portfolio_history(period_key: str) -> PortfolioHistoryResponse:
    period, timeframe = PERIOD_MAP.get(period_key, ("1M", "1D"))
    client = get_alpaca()
    data = await client.trading_request(
        "GET",
        f"/v2/account/portfolio/history?period={period}&timeframe={timeframe}",
    )
    timestamps = data.get("timestamp") or []
    equities = data.get("equity") or []
    pls = data.get("profit_loss") or []
    pl_pcts = data.get("profit_loss_pct") or []
    points: list[PnlPoint] = []
    cumulative = 0.0
    for i, ts in enumerate(timestamps):
        pl = float(pls[i]) if i < len(pls) else 0.0
        cumulative += pl
        points.append(
            PnlPoint(
                time=int(ts),
                equity=float(equities[i]) if i < len(equities) else 0.0,
                profit_loss=round(pl, 2),
                profit_loss_pct=round(float(pl_pcts[i]) if i < len(pl_pcts) else 0.0, 4),
                cumulative_pnl=round(cumulative, 2),
            )
        )
    if points and all(p.profit_loss == 0 for p in points) and len(points) > 1:
        base = points[0].equity
        cumulative = 0.0
        for p in points:
            cumulative = round(p.equity - base, 2)
            p.cumulative_pnl = cumulative
        total = points[-1].cumulative_pnl
    else:
        total = round(cumulative, 2)
    return PortfolioHistoryResponse(period=period_key, points=points, total_pnl=total)


async def _fetch_all_fills() -> list[dict]:
    client = get_alpaca()
    all_rows: list[dict] = []
    page_token: str | None = None
    for _ in range(15):
        path = "/v2/account/activities?activity_types=FILL&direction=asc&page_size=100"
        if page_token:
            path += f"&page_token={page_token}"
        rows = await client.trading_request("GET", path)
        if not isinstance(rows, list) or not rows:
            break
        all_rows.extend(rows)
        if len(rows) < 100:
            break
        page_token = rows[-1].get("id")
        if not page_token:
            break
    return all_rows


def _parse_time(raw: str) -> datetime:
    return datetime.fromisoformat(raw.replace("Z", "+00:00"))


def _aggregate_fills_to_orders(fills: list[dict]) -> list[dict]:
    """Merge partial fills of the same order into one execution leg."""
    legs: dict[str, dict] = {}
    for f in fills:
        oid = str(f.get("order_id") or f.get("id") or "")
        if not oid:
            continue
        sym = (f.get("symbol") or "").upper()
        side = (f.get("side") or "").lower()
        qty = float(f.get("qty") or 0)
        price = float(f.get("price") or 0)
        raw_t = f.get("transaction_time")
        if not sym or qty <= 0 or price <= 0 or not raw_t or side not in ("buy", "sell"):
            continue
        t = _parse_time(raw_t)
        leg = legs.get(oid)
        if leg is None:
            legs[oid] = {
                "symbol": sym,
                "side": side,
                "qty": qty,
                "notional": qty * price,
                "time": t,
            }
        else:
            leg["qty"] += qty
            leg["notional"] += qty * price
            if t < leg["time"]:
                leg["time"] = t
    out: list[dict] = []
    for leg in legs.values():
        if leg["qty"] <= 0:
            continue
        out.append(
            {
                "symbol": leg["symbol"],
                "side": leg["side"],
                "qty": leg["qty"],
                "price": leg["notional"] / leg["qty"],
                "time": leg["time"],
            }
        )
    out.sort(key=lambda x: x["time"])
    return out


def _process_symbol_legs(legs: list[dict]) -> list[tuple[float, float]]:
    """Track long-biased open -> flat cycles; one open = one completed trade."""
    closed: list[tuple[float, float]] = []
    qty = 0.0
    avg_cost = 0.0
    open_time: datetime | None = None
    round_pnl = 0.0

    def _close(end_time: datetime) -> None:
        nonlocal open_time, round_pnl
        if open_time is None:
            return
        hold_h = max((end_time - open_time).total_seconds() / 3600.0, 0.0)
        closed.append((round(round_pnl, 2), hold_h))
        open_time = None
        round_pnl = 0.0

    for leg in legs:
        side = leg["side"]
        remaining = float(leg["qty"])
        price = float(leg["price"])
        t = leg["time"]

        if side == "buy":
            while remaining > 1e-9:
                if qty < 0:
                    cover = min(remaining, abs(qty))
                    round_pnl += (avg_cost - price) * cover
                    qty += cover
                    remaining -= cover
                    if abs(qty) < 1e-9:
                        qty = 0.0
                        _close(t)
                if remaining <= 1e-9:
                    break
                if qty == 0:
                    open_time = t
                    round_pnl = 0.0
                new_qty = qty + remaining
                avg_cost = (avg_cost * qty + price * remaining) / new_qty if new_qty > 0 else price
                qty = new_qty
                remaining = 0.0

        else:  # sell — only closes an existing long; never opens short
            if qty <= 1e-9:
                continue
            sell = min(remaining, qty)
            round_pnl += (price - avg_cost) * sell
            qty -= sell
            remaining -= sell
            if abs(qty) < 1e-9:
                qty = 0.0
                _close(t)

    return closed


def _analyze_fills(fills: list[dict]) -> tuple[list[tuple[float, float]], float]:
    """Return completed opens (flat -> position -> flat) as (pnl, hold_hours)."""
    orders = _aggregate_fills_to_orders(fills)
    by_sym: dict[str, list[dict]] = defaultdict(list)
    for leg in orders:
        by_sym[leg["symbol"]].append(leg)

    closed: list[tuple[float, float]] = []
    for sym_legs in by_sym.values():
        sym_legs.sort(key=lambda x: x["time"])
        closed.extend(_process_symbol_legs(sym_legs))

    total = round(sum(p for p, _ in closed), 2)
    return closed, total


async def get_trade_analytics() -> TradeAnalytics:
    fills = await _fetch_all_fills()
    closed, total_realized = _analyze_fills(fills)

    wins = [p for p, _ in closed if p > 0]
    losses = [p for p, _ in closed if p < 0]
    holds = [h for _, h in closed]

    win_rate = round(len(wins) / len(closed) * 100, 1) if closed else 0.0
    gross_win = sum(wins)
    gross_loss = abs(sum(losses))
    avg_win = round(gross_win / len(wins), 2) if wins else 0.0
    avg_loss = round(gross_loss / len(losses), 2) if losses else 0.0
    # 盈亏比 = 平均盈利 / 平均亏损（比例，不是金额）
    if avg_loss > 0:
        profit_factor = round(avg_win / avg_loss, 2)
    elif avg_win > 0:
        profit_factor = 0.0
    else:
        profit_factor = 0.0
    avg_hold = round(sum(holds) / len(holds), 1) if holds else 0.0

    history = await get_portfolio_history("1y")
    by_date_pl: dict[str, float] = defaultdict(float)
    by_date_eq: dict[str, list[float]] = defaultdict(list)
    for p in history.points:
        d = datetime.fromtimestamp(p.time, tz=timezone.utc).strftime("%Y-%m-%d")
        by_date_pl[d] += p.profit_loss
        by_date_eq[d].append(p.equity)
    by_date: dict[str, float] = {}
    for d, eqs in by_date_eq.items():
        pl = by_date_pl[d]
        if pl == 0 and len(eqs) > 1:
            pl = eqs[-1] - eqs[0]
        by_date[d] = round(pl, 2)
    daily = [DailyPnl(date=d, pnl=v) for d, v in sorted(by_date.items())]

    pnls = [d.pnl for d in daily]
    return TradeAnalytics(
        total_trades=len(closed),
        win_trades=len(wins),
        loss_trades=len(losses),
        win_rate=win_rate,
        profit_factor=profit_factor,
        avg_win=avg_win,
        avg_loss=avg_loss,
        avg_hold_hours=avg_hold,
        total_realized_pnl=total_realized,
        best_day_pnl=round(max(pnls), 2) if pnls else 0.0,
        worst_day_pnl=round(min(pnls), 2) if pnls else 0.0,
        daily_pnl=daily,
    )
