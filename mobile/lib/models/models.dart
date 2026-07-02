class Quote {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePct;
  final double prevClose;
  final double bid;
  final double ask;
  final double bidSize;
  final double askSize;

  Quote({
    required this.symbol,
    this.name = '',
    required this.price,
    required this.change,
    required this.changePct,
    required this.prevClose,
    this.bid = 0,
    this.ask = 0,
    this.bidSize = 0,
    this.askSize = 0,
  });

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        symbol: j['symbol'] as String,
        name: j['name'] as String? ?? j['symbol'] as String,
        price: (j['price'] as num).toDouble(),
        change: (j['change'] as num).toDouble(),
        changePct: (j['change_pct'] as num).toDouble(),
        prevClose: (j['prev_close'] as num).toDouble(),
        bid: (j['bid'] as num?)?.toDouble() ?? 0,
        ask: (j['ask'] as num?)?.toDouble() ?? 0,
        bidSize: (j['bid_size'] as num?)?.toDouble() ?? 0,
        askSize: (j['ask_size'] as num?)?.toDouble() ?? 0,
      );
}

class Bar {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;

  Bar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  factory Bar.fromJson(Map<String, dynamic> j) => Bar(
        time: j['time'] as int,
        open: (j['open'] as num).toDouble(),
        high: (j['high'] as num).toDouble(),
        low: (j['low'] as num).toDouble(),
        close: (j['close'] as num).toDouble(),
      );
}

class SearchResult {
  final String symbol;
  final String name;

  SearchResult({required this.symbol, required this.name});

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        symbol: j['symbol'] as String,
        name: j['name'] as String? ?? j['symbol'] as String,
      );
}

class NewsItem {
  final String id;
  final String headline;
  final String source;
  final String url;
  final int createdAt;
  final List<String> symbols;

  NewsItem({
    required this.id,
    required this.headline,
    this.source = '',
    this.url = '',
    this.createdAt = 0,
    this.symbols = const [],
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: j['id'] as String? ?? '',
        headline: j['headline'] as String? ?? '',
        source: j['source'] as String? ?? '',
        url: j['url'] as String? ?? '',
        createdAt: j['created_at'] as int? ?? 0,
        symbols: (j['symbols'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

class OrderBookLevel {
  final double price;
  final double size;
  final bool isReal;

  OrderBookLevel({
    required this.price,
    required this.size,
    this.isReal = true,
  });

  factory OrderBookLevel.fromJson(Map<String, dynamic> j) => OrderBookLevel(
        price: (j['price'] as num).toDouble(),
        size: (j['size'] as num).toDouble(),
        isReal: j['is_real'] as bool? ?? true,
      );
}

class OrderBook {
  final String symbol;
  final List<OrderBookLevel> asks;
  final List<OrderBookLevel> bids;

  OrderBook({
    required this.symbol,
    required this.asks,
    required this.bids,
  });

  factory OrderBook.fromJson(Map<String, dynamic> j) => OrderBook(
        symbol: j['symbol'] as String,
        asks: (j['asks'] as List<dynamic>)
            .map((e) => OrderBookLevel.fromJson(e as Map<String, dynamic>))
            .toList(),
        bids: (j['bids'] as List<dynamic>)
            .map((e) => OrderBookLevel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AccountSummary {
  final double equity;
  final double cash;
  final double buyingPower;
  final double marginBuyingPower;
  final double dailyPnl;
  final double dailyPnlPct;

  AccountSummary({
    required this.equity,
    required this.cash,
    required this.buyingPower,
    required this.marginBuyingPower,
    required this.dailyPnl,
    required this.dailyPnlPct,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> j) => AccountSummary(
        equity: (j['equity'] as num).toDouble(),
        cash: (j['cash'] as num).toDouble(),
        buyingPower: (j['cash'] as num).toDouble(),
        marginBuyingPower: (j['buying_power'] as num?)?.toDouble() ??
            (j['margin_buying_power'] as num?)?.toDouble() ??
            (j['cash'] as num).toDouble(),
        dailyPnl: (j['daily_pnl'] as num).toDouble(),
        dailyPnlPct: (j['daily_pnl_pct'] as num).toDouble(),
      );
}

class Position {
  final String symbol;
  final double qty;
  final double avgCost;
  final double price;
  final double pnl;
  final double pnlPct;
  final String side;

  Position({
    required this.symbol,
    required this.qty,
    required this.avgCost,
    required this.price,
    required this.pnl,
    required this.pnlPct,
    required this.side,
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        symbol: j['symbol'] as String,
        qty: (j['qty'] as num).toDouble(),
        avgCost: (j['avg_cost'] as num).toDouble(),
        price: (j['price'] as num).toDouble(),
        pnl: (j['pnl'] as num).toDouble(),
        pnlPct: (j['pnl_pct'] as num).toDouble(),
        side: j['side'] as String? ?? 'long',
      );
}

class OrderModel {
  final String id;
  final String symbol;
  final String side;
  final double qty;
  final String type;
  final String status;
  final double? filledAvgPrice;
  final String? submittedAt;

  OrderModel({
    required this.id,
    required this.symbol,
    required this.side,
    required this.qty,
    required this.type,
    required this.status,
    this.filledAvgPrice,
    this.submittedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        side: j['side'] as String,
        qty: (j['qty'] as num).toDouble(),
        type: j['type'] as String,
        status: j['status'] as String,
        filledAvgPrice: j['filled_avg_price'] != null
            ? (j['filled_avg_price'] as num).toDouble()
            : null,
        submittedAt: j['submitted_at'] as String?,
      );
}

class OptionRow {
  final double strike;
  final double? callBid;
  final double? callAsk;
  final double? callLast;
  final String? callOcc;
  final double? putBid;
  final double? putAsk;
  final double? putLast;
  final String? putOcc;

  OptionRow({
    required this.strike,
    this.callBid,
    this.callAsk,
    this.callLast,
    this.callOcc,
    this.putBid,
    this.putAsk,
    this.putLast,
    this.putOcc,
  });

  factory OptionRow.fromJson(Map<String, dynamic> j) => OptionRow(
        strike: (j['strike'] as num).toDouble(),
        callBid: (j['call_bid'] as num?)?.toDouble(),
        callAsk: (j['call_ask'] as num?)?.toDouble(),
        callLast: (j['call_last'] as num?)?.toDouble(),
        callOcc: j['call_occ'] as String?,
        putBid: (j['put_bid'] as num?)?.toDouble(),
        putAsk: (j['put_ask'] as num?)?.toDouble(),
        putLast: (j['put_last'] as num?)?.toDouble(),
        putOcc: j['put_occ'] as String?,
      );
}

class OptionsChain {
  final String symbol;
  final String expiry;
  final double spot;
  final List<String> expirations;
  final List<OptionRow> chain;

  OptionsChain({
    required this.symbol,
    required this.expiry,
    required this.spot,
    required this.expirations,
    required this.chain,
  });

  factory OptionsChain.fromJson(Map<String, dynamic> j) => OptionsChain(
        symbol: j['symbol'] as String,
        expiry: j['expiry'] as String,
        spot: (j['spot'] as num).toDouble(),
        expirations: (j['expirations'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        chain: (j['chain'] as List<dynamic>? ?? [])
            .map((e) => OptionRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PnlPoint {
  final int time;
  final double equity;
  final double profitLoss;
  final double profitLossPct;
  final double cumulativePnl;

  PnlPoint({
    required this.time,
    required this.equity,
    required this.profitLoss,
    required this.profitLossPct,
    required this.cumulativePnl,
  });

  factory PnlPoint.fromJson(Map<String, dynamic> j) => PnlPoint(
        time: j['time'] as int,
        equity: (j['equity'] as num).toDouble(),
        profitLoss: (j['profit_loss'] as num).toDouble(),
        profitLossPct: (j['profit_loss_pct'] as num).toDouble(),
        cumulativePnl: (j['cumulative_pnl'] as num).toDouble(),
      );
}

class PortfolioHistory {
  final String period;
  final List<PnlPoint> points;
  final double totalPnl;

  PortfolioHistory({
    required this.period,
    required this.points,
    required this.totalPnl,
  });

  factory PortfolioHistory.fromJson(Map<String, dynamic> j) => PortfolioHistory(
        period: j['period'] as String,
        points: (j['points'] as List<dynamic>? ?? [])
            .map((e) => PnlPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPnl: (j['total_pnl'] as num).toDouble(),
      );
}

class DailyPnl {
  final String date;
  final double pnl;

  DailyPnl({required this.date, required this.pnl});

  factory DailyPnl.fromJson(Map<String, dynamic> j) => DailyPnl(
        date: j['date'] as String,
        pnl: (j['pnl'] as num).toDouble(),
      );
}

class TradeAnalytics {
  final int totalTrades;
  final int winTrades;
  final int lossTrades;
  final double winRate;
  final double profitFactor;
  final double avgWin;
  final double avgLoss;
  final double avgHoldHours;
  final double totalRealizedPnl;
  final double bestDayPnl;
  final double worstDayPnl;
  final List<DailyPnl> dailyPnl;

  TradeAnalytics({
    required this.totalTrades,
    required this.winTrades,
    required this.lossTrades,
    required this.winRate,
    required this.profitFactor,
    required this.avgWin,
    required this.avgLoss,
    required this.avgHoldHours,
    required this.totalRealizedPnl,
    required this.bestDayPnl,
    required this.worstDayPnl,
    required this.dailyPnl,
  });

  factory TradeAnalytics.fromJson(Map<String, dynamic> j) => TradeAnalytics(
        totalTrades: j['total_trades'] as int? ?? 0,
        winTrades: j['win_trades'] as int? ?? 0,
        lossTrades: j['loss_trades'] as int? ?? 0,
        winRate: (j['win_rate'] as num?)?.toDouble() ?? 0,
        profitFactor: (j['profit_factor'] as num?)?.toDouble() ?? 0,
        avgWin: (j['avg_win'] as num?)?.toDouble() ?? 0,
        avgLoss: (j['avg_loss'] as num?)?.toDouble() ?? 0,
        avgHoldHours: (j['avg_hold_hours'] as num?)?.toDouble() ?? 0,
        totalRealizedPnl: (j['total_realized_pnl'] as num?)?.toDouble() ?? 0,
        bestDayPnl: (j['best_day_pnl'] as num?)?.toDouble() ?? 0,
        worstDayPnl: (j['worst_day_pnl'] as num?)?.toDouble() ?? 0,
        dailyPnl: (j['daily_pnl'] as List<dynamic>? ?? [])
            .map((e) => DailyPnl.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
