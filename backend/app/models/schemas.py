from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    ok: bool = True
    alpaca: bool
    paper: bool
    version: str = "0.1.0"


class Quote(BaseModel):
    symbol: str
    name: str = ""
    price: float
    change: float
    change_pct: float
    prev_close: float
    bid: float = 0
    ask: float = 0
    bid_size: float = 0
    ask_size: float = 0


class OrderBookLevel(BaseModel):
    price: float
    size: float


class OrderBookResponse(BaseModel):
    symbol: str
    asks: list[OrderBookLevel]
    bids: list[OrderBookLevel]


class Bar(BaseModel):
    time: int
    open: float
    high: float
    low: float
    close: float


class BarsResponse(BaseModel):
    symbol: str
    timeframe: str
    bars: list[Bar]


class SearchResult(BaseModel):
    symbol: str
    name: str


class NewsItem(BaseModel):
    id: str
    headline: str
    source: str = ""
    url: str = ""
    created_at: int = 0
    symbols: list[str] = Field(default_factory=list)


class OptionRow(BaseModel):
    strike: float
    call_bid: float | None = None
    call_ask: float | None = None
    call_last: float | None = None
    call_occ: str | None = None
    put_bid: float | None = None
    put_ask: float | None = None
    put_last: float | None = None
    put_occ: str | None = None


class OptionsChainResponse(BaseModel):
    symbol: str
    expiry: str
    spot: float
    expirations: list[str] = Field(default_factory=list)
    chain: list[OptionRow] = Field(default_factory=list)


class AccountSummary(BaseModel):
    equity: float
    cash: float
    buying_power: float
    daily_pnl: float
    daily_pnl_pct: float


class Position(BaseModel):
    symbol: str
    qty: float
    avg_cost: float
    price: float
    pnl: float
    pnl_pct: float
    side: str = "long"


class Order(BaseModel):
    id: str
    symbol: str
    side: str
    qty: float
    type: str
    status: str
    filled_avg_price: float | None = None
    submitted_at: str | None = None


class SubmitOrderRequest(BaseModel):
    symbol: str
    qty: float
    side: str
    type: str = "market"
    time_in_force: str = "day"
    limit_price: float | None = None
    stop_price: float | None = None


class ClosePositionRequest(BaseModel):
    symbol: str
    percent: float = 100.0


class DismissPositionRequest(BaseModel):
    symbol: str


class PositionBracketRequest(BaseModel):
    symbol: str
    take_profit_price: float | None = None
    stop_loss_price: float | None = None


class AppSettings(BaseModel):
    dark_mode: bool = True
    show_greeks: bool = False
    show_advanced: bool = False
    api_base_url: str = "http://127.0.0.1:8000"
    ws_url: str = "ws://127.0.0.1:8000/ws"


class PnlPoint(BaseModel):
    time: int
    equity: float
    profit_loss: float
    profit_loss_pct: float
    cumulative_pnl: float = 0


class PortfolioHistoryResponse(BaseModel):
    period: str
    points: list[PnlPoint] = Field(default_factory=list)
    total_pnl: float = 0


class DailyPnl(BaseModel):
    date: str
    pnl: float


class TradeAnalytics(BaseModel):
    total_trades: int = 0
    win_trades: int = 0
    loss_trades: int = 0
    win_rate: float = 0
    profit_factor: float = 0
    avg_win: float = 0
    avg_loss: float = 0
    avg_hold_hours: float = 0
    total_realized_pnl: float = 0
    best_day_pnl: float = 0
    worst_day_pnl: float = 0
    daily_pnl: list[DailyPnl] = Field(default_factory=list)
