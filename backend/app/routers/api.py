from fastapi import APIRouter, HTTPException, Query

from app.config import get_settings
from app.models.schemas import (
    AccountSummary,
    BarsResponse,
    ClosePositionRequest,
    DismissPositionRequest,
    HealthResponse,
    Order,
    OrderBookResponse,
    NewsItem,
    PortfolioHistoryResponse,
    Position,
    PositionBracketRequest,
    Quote,
    SearchResult,
    SubmitOrderRequest,
    TradeAnalytics,
)
from app.services import analytics as analytics_svc
from app.services import market_data as market_svc
from app.services import options as opt_svc
from app.services import trading as trading_svc

router = APIRouter(prefix="/api", tags=["market"])


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    s = get_settings()
    return HealthResponse(ok=True, alpaca=s.alpaca_configured, paper=s.is_paper)


@router.get("/quote", response_model=Quote)
async def quote(symbol: str) -> Quote:
    s = get_settings()
    if not s.alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await trading_svc.get_quote(
        symbol, s.alpaca_data_feed, s.alpaca_option_feed
    )


@router.get("/orderbook", response_model=OrderBookResponse)
async def orderbook(symbol: str, levels: int = 5) -> OrderBookResponse:
    s = get_settings()
    if not s.alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    levels = max(1, min(levels, 10))
    return await trading_svc.get_order_book(
        symbol, s.alpaca_data_feed, s.alpaca_option_feed, levels
    )


@router.get("/quotes")
async def quotes(symbols: str = Query(..., description="comma-separated")) -> dict[str, Quote]:
    s = get_settings()
    if not s.alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    out: dict[str, Quote] = {}
    for sym in symbols.split(","):
        sym = sym.strip().upper()
        if sym:
            out[sym] = await trading_svc.get_quote(
                sym, s.alpaca_data_feed, s.alpaca_option_feed
            )
    return out


@router.get("/bars", response_model=BarsResponse)
async def bars(symbol: str, timeframe: str = "5m") -> BarsResponse:
    s = get_settings()
    if not s.alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    data = await trading_svc.get_bars(
        symbol, timeframe, s.alpaca_data_feed, s.alpaca_option_feed
    )
    return BarsResponse(symbol=symbol.upper(), timeframe=timeframe, bars=data)


@router.get("/search", response_model=list[SearchResult])
async def search(q: str) -> list[SearchResult]:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await market_svc.search_symbols(q)


@router.get("/news", response_model=list[NewsItem])
async def news(limit: int = 15, symbols: str | None = None) -> list[NewsItem]:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await market_svc.get_news(limit=min(limit, 30), symbols=symbols)


@router.get("/options/expirations")
async def option_expirations(symbol: str) -> dict:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    exps = await opt_svc.get_option_expirations(symbol)
    return {"symbol": symbol.upper(), "expirations": exps}


@router.get("/options/chain")
async def options_chain(symbol: str, expiry: str | None = None, spot: float | None = None):
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await opt_svc.get_options_chain(symbol, expiry, spot)


@router.get("/account", response_model=AccountSummary)
async def account() -> AccountSummary:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await trading_svc.get_account()


@router.get("/portfolio/history", response_model=PortfolioHistoryResponse)
async def portfolio_history(period: str = "7d") -> PortfolioHistoryResponse:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    if period not in ("7d", "1m", "1y"):
        raise HTTPException(400, "period must be 7d, 1m, or 1y")
    return await analytics_svc.get_portfolio_history(period)


@router.get("/analytics/trades", response_model=TradeAnalytics)
async def trade_analytics() -> TradeAnalytics:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await analytics_svc.get_trade_analytics()


@router.get("/positions", response_model=list[Position])
async def positions() -> list[Position]:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await trading_svc.get_positions()


@router.post("/positions/settle-expired")
async def settle_expired_positions() -> dict:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await trading_svc.force_settle_expired_options()


@router.get("/orders", response_model=list[Order])
async def orders(limit: int = 50) -> list[Order]:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await trading_svc.get_orders(limit)


@router.post("/orders", response_model=Order)
async def create_order(body: SubmitOrderRequest) -> Order:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    return await trading_svc.submit_order(
        body.symbol,
        body.qty,
        body.side,
        body.type,
        body.time_in_force,
        body.limit_price,
        body.stop_price,
    )


@router.post("/positions/dismiss")
async def dismiss_position(body: DismissPositionRequest) -> dict:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    try:
        return await trading_svc.dismiss_position(body.symbol)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e


@router.post("/positions/close", response_model=Order)
async def close_position(body: ClosePositionRequest) -> Order:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    try:
        return await trading_svc.close_position(body.symbol, body.percent)
    except ValueError as e:
        msg = str(e)
        if msg == "no_liquidity":
            raise HTTPException(409, "no_liquidity") from e
        raise HTTPException(400, msg) from e


@router.post("/positions/bracket", response_model=list[Order])
async def position_bracket(body: PositionBracketRequest) -> list[Order]:
    if not get_settings().alpaca_configured:
        raise HTTPException(503, "Alpaca not configured")
    try:
        return await trading_svc.set_position_bracket(
            body.symbol, body.take_profit_price, body.stop_loss_price
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
