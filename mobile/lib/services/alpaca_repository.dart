import 'dart:collection';

import 'package:dio/dio.dart';

import '../core/alpaca_config.dart';
import '../models/models.dart';
import 'alpaca_client.dart';
import 'dismissed_positions_store.dart';

class MarketSnapshot {
  const MarketSnapshot({required this.quote, required this.orderBook});

  final Quote quote;
  final OrderBook orderBook;
}

class _MarketCacheEntry {
  _MarketCacheEntry(this.at, this.snapshot);

  final DateTime at;
  final MarketSnapshot snapshot;
}

final _occRe = RegExp(r'^([A-Z]{1,6})(\d{6})([CP])(\d{8})$');

class _TfSpec {
  const _TfSpec(this.alpaca, this.days, this.limit, this.resample);
  final String alpaca;
  final int days;
  final int limit;
  final int resample;
}

const _tfMap = <String, _TfSpec>{
  '1m': _TfSpec('1Min', 2, 500, 1),
  '5m': _TfSpec('5Min', 5, 400, 1),
  '15m': _TfSpec('15Min', 7, 320, 1),
  '1h': _TfSpec('1Hour', 30, 240, 1),
  '4h': _TfSpec('1Hour', 90, 360, 4),
  '1d': _TfSpec('1Day', 365, 260, 1),
  '1H': _TfSpec('1Hour', 30, 240, 1),
  '1D': _TfSpec('1Day', 365, 260, 1),
  '1W': _TfSpec('1Week', 365 * 3, 160, 1),
};

const _periodMap = <String, (String, String)>{
  '7d': ('1W', '1H'),
  '1m': ('1M', '1D'),
  '1y': ('1A', '1D'),
};

class AlpacaRepository {
  AlpacaRepository(
    this.creds, {
    DismissedPositionsStore? dismissed,
    this.depthApiUrl = '',
  })  : _client = AlpacaClient(creds),
        _dismissed = dismissed ?? DismissedPositionsStore();

  final AlpacaCredentials creds;
  final String depthApiUrl;
  final AlpacaClient _client;
  final DismissedPositionsStore _dismissed;

  final _expCache = <String, (DateTime, List<String>)>{};
  final _chainCache = <String, (DateTime, OptionsChain)>{};
  List<Map<String, dynamic>>? _assetsCache;
  final _quoteBaseline = <String, Quote>{};
  final _marketCache = <String, _MarketCacheEntry>{};
  final _sparkCache = <String, (DateTime, List<Bar>)>{};

  static const _marketCacheTtl = Duration(milliseconds: 350);
  static const _sparkCacheTtl = Duration(minutes: 3);
  static const _depthLevels = 5;

  final Dio _external = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  bool get isConfigured => creds.isConfigured;

  Future<AccountSummary> getAccount() async {
    final a = await _client.tradingGet('/v2/account') as Map<String, dynamic>;
    final equity = _dbl(a['equity']);
    final last = _dbl(a['last_equity']);
    final daily = equity - last;
    return AccountSummary(
      equity: equity,
      cash: _dbl(a['cash']),
      buyingPower: _dbl(a['buying_power']),
      marginBuyingPower: _dbl(a['regt_buying_power']) > 0
          ? _dbl(a['regt_buying_power'])
          : _dbl(a['buying_power']),
      dailyPnl: daily,
      dailyPnlPct: last != 0 ? daily / last * 100 : 0,
    );
  }

  Future<List<Position>> getPositions() async {
    final dismissed = await _dismissed.load();
    final rows = await _fetchPositionRows();
    final filtered = rows.where((r) {
      final sym = (r['symbol'] as String? ?? '').toUpperCase();
      return !dismissed.contains(sym);
    }).toList();
    return _rowsToPositions(filtered);
  }

  Future<void> dismissPosition(String symbol) async {
    final sym = symbol.toUpperCase();
    final rows = await _fetchPositionRows();
    if (_rowForSymbol(rows, sym) == null) {
      throw AlpacaApiException(400, 'no position for $sym');
    }
    await _dismissed.dismiss(sym);
  }

  Future<List<OrderModel>> getOrders({int limit = 50}) async {
    final rows = await _client.tradingGet(
      '/v2/orders?status=all&limit=$limit&direction=desc',
    ) as List<dynamic>;
    return rows.map((o) => _orderFromJson(o as Map<String, dynamic>)).toList();
  }

  Future<OrderModel> submitOrder({
    required String symbol,
    required double qty,
    required String side,
    required String type,
    String timeInForce = 'day',
    double? limitPrice,
    double? stopPrice,
  }) async {
    final body = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'qty': qty.toString(),
      'side': side,
      'type': type,
      'time_in_force': timeInForce,
    };
    if (limitPrice != null) body['limit_price'] = limitPrice.toString();
    if (stopPrice != null) body['stop_price'] = stopPrice.toString();
    final o = await _client.tradingPost('/v2/orders', body: body) as Map<String, dynamic>;
    return _orderFromJson(o);
  }

  Future<OrderModel> closePosition(String symbol, double percent) async {
    final sym = symbol.toUpperCase();
    final rows = await _fetchPositionRows();
    final row = _rowForSymbol(rows, sym);
    if (row == null) throw AlpacaApiException(400, 'no position for $sym');

    var qty = (row['qty'] as num).abs().toDouble();
    final pct = percent.clamp(1.0, 100.0);
    if (pct < 99.9) {
      if (_occRe.hasMatch(sym)) {
        qty = (qty * pct / 100).floorToDouble().clamp(1.0, qty);
      } else {
        qty = double.parse((qty * pct / 100).toStringAsFixed(4));
      }
    }
    if (qty <= 0) throw AlpacaApiException(400, 'close qty must be positive');

    final closeSide = (row['qty'] as num).toDouble() > 0 ? 'sell' : 'buy';

    if (_occRe.hasMatch(sym) && (_isWorthlessRow(row) || pct >= 99.9)) {
      final partial = Map<String, dynamic>.from(row);
      partial['qty'] = closeSide == 'sell' ? qty : -qty;
      final result = await _tryCloseIlliquidOption(partial);
      if (result == 'liquidated') {
        return OrderModel(
          id: 'liquidated',
          symbol: sym,
          side: closeSide,
          qty: qty,
          type: 'market',
          status: 'filled',
          filledAvgPrice: 0,
          submittedAt: DateTime.now().toUtc().toIso8601String(),
        );
      }
      if (result == 'penny_limit' || result == 'market') {
        final orders = await _client.tradingGet(
          '/v2/orders?status=open&symbols=$sym&limit=1&direction=desc',
        ) as List<dynamic>;
        if (orders.isNotEmpty) {
          return _orderFromJson(orders.first as Map<String, dynamic>);
        }
      }
      throw AlpacaApiException(409, 'no_liquidity');
    }

    return submitOrder(symbol: sym, qty: qty, side: closeSide, type: 'market');
  }

  Future<List<OrderModel>> setPositionBracket({
    required String symbol,
    double? takeProfitPrice,
    double? stopLossPrice,
  }) async {
    if (takeProfitPrice == null && stopLossPrice == null) {
      throw AlpacaApiException(400, 'take_profit_price or stop_loss_price required');
    }
    final positions = await getPositions();
    Position? pos;
    for (final p in positions) {
      if (p.symbol.toUpperCase() == symbol.toUpperCase()) {
        pos = p;
        break;
      }
    }
    if (pos == null) throw AlpacaApiException(400, 'no position for $symbol');

    final closeSide = pos.side == 'long' ? 'sell' : 'buy';
    final out = <OrderModel>[];
    if (takeProfitPrice != null) {
      out.add(await submitOrder(
        symbol: pos.symbol,
        qty: pos.qty,
        side: closeSide,
        type: 'limit',
        timeInForce: 'gtc',
        limitPrice: takeProfitPrice,
      ));
    }
    if (stopLossPrice != null) {
      out.add(await submitOrder(
        symbol: pos.symbol,
        qty: pos.qty,
        side: closeSide,
        type: 'stop',
        timeInForce: 'gtc',
        stopPrice: stopLossPrice,
      ));
    }
    return out;
  }

  Future<Quote> getQuote(String symbol) async {
    final sym = symbol.toUpperCase();
    final q = _occRe.hasMatch(sym)
        ? await _optionQuote(sym)
        : _parseStockSnapshot(
            sym,
            await _client.dataGet('/v2/stocks/$sym/snapshot?feed=${creds.dataFeed}')
                as Map<String, dynamic>,
          );
    _quoteBaseline[sym] = q;
    return q;
  }

  /// Single cached fetch — quote + order book share the same Alpaca BBO snapshot.
  Future<MarketSnapshot> getMarketSnapshot(String symbol) async {
    final sym = symbol.toUpperCase();
    final hit = _marketCache[sym];
    if (hit != null && DateTime.now().difference(hit.at) < _marketCacheTtl) {
      return hit.snapshot;
    }

    final quote = _occRe.hasMatch(sym) ? await _optionQuoteLive(sym) : await _fetchStockQuoteLive(sym);
    var book = _orderBookFromQuote(quote, sym);
    book = await _mergeCustomDepth(book, sym);
    final snapshot = MarketSnapshot(quote: quote, orderBook: book);
    _marketCache[sym] = _MarketCacheEntry(DateTime.now(), snapshot);
    _quoteBaseline[sym] = quote;
    return snapshot;
  }

  /// Lightweight latest trade + quote — for fast UI refresh on the active symbol.
  Future<Quote> getQuoteLive(String symbol) async {
    return (await getMarketSnapshot(symbol)).quote;
  }

  Future<Quote> _fetchStockQuoteLive(String sym) async {
    try {
      final results = await Future.wait<Object?>([
        _client.dataGet('/v2/stocks/trades/latest?symbols=$sym&feed=${creds.dataFeed}'),
        _client.dataGet('/v2/stocks/quotes/latest?symbols=$sym&feed=${creds.dataFeed}'),
      ]);
      final tradeRoot = results[0] as Map<String, dynamic>? ?? {};
      final quoteRoot = results[1] as Map<String, dynamic>? ?? {};
      final trade = (tradeRoot['trades'] as Map<String, dynamic>?)?[sym] as Map<String, dynamic>? ?? {};
      final lq = (quoteRoot['quotes'] as Map<String, dynamic>?)?[sym] as Map<String, dynamic>? ?? {};
      return _mergeLiveStockQuote(sym, trade, lq);
    } catch (_) {
      return getQuote(sym);
    }
  }

  Future<Map<String, Quote>> getQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final stocks = <String>[];
    final options = <String>[];
    for (final s in symbols) {
      final sym = s.toUpperCase();
      if (_occRe.hasMatch(sym)) {
        options.add(sym);
      } else {
        stocks.add(sym);
      }
    }
    final out = <String, Quote>{};
    if (stocks.isNotEmpty) {
      try {
        final data = await _client.dataGet(
          '/v2/stocks/snapshots?symbols=${stocks.join(',')}&feed=${creds.dataFeed}',
        ) as Map<String, dynamic>;
        final snaps = _stockSnapshotsFromResponse(data);
        for (final sym in stocks) {
          final snap = snaps[sym] as Map<String, dynamic>?;
          if (snap != null) {
            final q = _parseStockSnapshot(sym, snap);
            _quoteBaseline[sym] = q;
            out[sym] = q;
          }
        }
      } catch (_) {}
      for (final sym in stocks) {
        if (out.containsKey(sym)) continue;
        try {
          out[sym] = await getQuote(sym);
        } catch (_) {}
      }
    }
    for (final occ in options) {
      try {
        out[occ] = await _optionQuote(occ);
      } catch (_) {}
    }
    return out;
  }

  Future<OrderBook> getOrderBook(String symbol, {int levels = 5}) async {
    final snap = await getMarketSnapshot(symbol);
    return _trimBookLevels(snap.orderBook, levels.clamp(1, _depthLevels));
  }

  Future<List<Bar>> getBars(String symbol, String timeframe) async {
    final sym = symbol.toUpperCase();
    if (_occRe.hasMatch(sym)) return _optionBars(sym, timeframe);
    final spec = _tfMap[timeframe] ?? _tfMap['1D']!;
    final start = DateTime.now().toUtc().subtract(Duration(days: spec.days));
    final startStr = '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    final data = await _client.dataGet(
      '/v2/stocks/bars?symbols=$sym&timeframe=${spec.alpaca}&start=$startStr'
      '&limit=${spec.limit}&feed=${creds.dataFeed}&adjustment=split',
    ) as Map<String, dynamic>;
    final raw = _barsRawForSymbol(data, sym);
    final bars = _parseBars(raw);
    return _resampleBars(bars, spec.resample);
  }

  /// Daily closes for watchlist line spark (lightweight, cached).
  Future<List<Bar>> getSparklineBars(String symbol) async {
    final sym = symbol.toUpperCase();
    final hit = _sparkCache[sym];
    if (hit != null && DateTime.now().difference(hit.$1) < _sparkCacheTtl) {
      return hit.$2;
    }
    const limit = 40;
    final start = DateTime.now().toUtc().subtract(const Duration(days: 90));
    final startStr = '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    try {
      final data = await _client.dataGet(
        '/v2/stocks/bars?symbols=$sym&timeframe=1Day&start=$startStr'
        '&limit=$limit&feed=${creds.dataFeed}&adjustment=split',
      ) as Map<String, dynamic>;
      var bars = _parseBars(_barsRawForSymbol(data, sym));
      if (bars.length > limit) bars = bars.sublist(bars.length - limit);
      _sparkCache[sym] = (DateTime.now(), bars);
      return bars;
    } catch (_) {
      return const [];
    }
  }

  List<dynamic> _barsRawForSymbol(Map<String, dynamic> data, String sym) {
    final bucket = data['bars'];
    if (bucket is Map<String, dynamic>) {
      return bucket[sym] as List<dynamic>? ??
          bucket[sym.toUpperCase()] as List<dynamic>? ??
          const [];
    }
    if (bucket is List<dynamic>) return bucket;
    return const [];
  }

  Future<List<SearchResult>> searchSymbols(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final upper = q.toUpperCase();
    try {
      final asset = await _client.tradingGet('/v2/assets/$upper') as Map<String, dynamic>;
      if (asset['tradable'] == true) {
        return [SearchResult(symbol: asset['symbol'] as String, name: asset['name'] as String? ?? upper)];
      }
    } catch (_) {}
    final assets = await _loadAssets();
    final out = <SearchResult>[];
    final qLower = q.toLowerCase();
    for (final a in assets) {
      final sym = a['symbol'] as String? ?? '';
      final name = a['name'] as String? ?? sym;
      if (upper.contains(sym) ||
          sym.startsWith(upper) ||
          name.toLowerCase().contains(qLower) ||
          name.toUpperCase().contains(upper)) {
        out.add(SearchResult(symbol: sym, name: name));
        if (out.length >= 12) break;
      }
    }
    return out;
  }

  Future<List<NewsItem>> getNews({int limit = 15, String? symbols}) async {
    var path = '/v1beta1/news?limit=${limit.clamp(1, 30)}&sort=desc';
    if (symbols != null && symbols.isNotEmpty) path += '&symbols=$symbols';
    final data = await _client.dataGet(path) as Map<String, dynamic>;
    final raw = data['news'] as List<dynamic>? ?? [];
    return raw.map((n) {
      final m = n as Map<String, dynamic>;
      final created = m['created_at'] as String? ?? '';
      var ts = 0;
      if (created.isNotEmpty) {
        try {
          ts = DateTime.parse(created.replaceFirst('Z', '+00:00')).millisecondsSinceEpoch ~/ 1000;
        } catch (_) {}
      }
      final syms = m['symbols'];
      return NewsItem(
        id: '${m['id'] ?? ''}',
        headline: m['headline'] as String? ?? '',
        source: m['source'] as String? ?? m['author'] as String? ?? '',
        url: m['url'] as String? ?? '',
        createdAt: ts,
        symbols: syms is List ? syms.map((e) => e.toString()).toList() : const [],
      );
    }).toList();
  }

  Future<OptionsChain> getOptionsChain(String symbol, {String? expiry}) async {
    final sym = symbol.toUpperCase();
    final cacheKey = '$sym:${expiry ?? ''}';
    final cached = _chainCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.$1).inSeconds < 30) {
      return cached.$2;
    }

    final spot = (await getQuote(sym)).price;
    final exps = await getOptionExpirations(sym);
    if (exps.isEmpty) {
      return OptionsChain(symbol: sym, expiry: '', spot: spot, expirations: [], chain: []);
    }
    final exp = expiry != null && exps.contains(expiry) ? expiry : exps.first;
    final band = _spotStrikeBand(spot);
    final data = await _client.dataGet(
      '/v1beta1/options/snapshots/$sym?feed=${creds.optionFeed}'
      '&expiration_date=$exp&strike_price_gte=${band.$1}&strike_price_lte=${band.$2}&limit=1000',
    ) as Map<String, dynamic>;
    var chain = _parseSnapshotChain(data['snapshots'] as Map<String, dynamic>? ?? {});
    if (chain.isEmpty) {
      chain = await _chainFromContracts(sym, exp, spot);
    }
    final result = OptionsChain(
      symbol: sym,
      expiry: exp,
      spot: double.parse(spot.toStringAsFixed(2)),
      expirations: exps,
      chain: chain,
    );
    _chainCache[cacheKey] = (DateTime.now(), result);
    return result;
  }

  Future<List<String>> getOptionExpirations(String symbol) async {
    final sym = symbol.toUpperCase();
    final cached = _expCache[sym];
    if (cached != null && DateTime.now().difference(cached.$1).inMinutes < 30) {
      return cached.$2;
    }
    final contracts = await _fetchAllContracts(sym);
    final dates = <String>{};
    for (final c in contracts) {
      final d = c['expiration_date'] as String?;
      if (d != null) dates.add(d);
    }
    final exps = dates.toList()..sort();
    if (exps.isNotEmpty) _expCache[sym] = (DateTime.now(), exps);
    return exps;
  }

  Future<PortfolioHistory> getPortfolioHistory(String periodKey) async {
    final mapped = _periodMap[periodKey] ?? _periodMap['1m']!;
    final data = await _client.tradingGet(
      '/v2/account/portfolio/history?period=${mapped.$1}&timeframe=${mapped.$2}',
    ) as Map<String, dynamic>;
    final timestamps = data['timestamp'] as List<dynamic>? ?? [];
    final equities = data['equity'] as List<dynamic>? ?? [];
    final pls = data['profit_loss'] as List<dynamic>? ?? [];
    final plPcts = data['profit_loss_pct'] as List<dynamic>? ?? [];
    final points = <PnlPoint>[];
    var cumulative = 0.0;
    for (var i = 0; i < timestamps.length; i++) {
      final pl = i < pls.length ? _dbl(pls[i]) : 0.0;
      cumulative += pl;
      points.add(PnlPoint(
        time: _int(timestamps[i]),
        equity: i < equities.length ? _dbl(equities[i]) : 0,
        profitLoss: double.parse(pl.toStringAsFixed(2)),
        profitLossPct: i < plPcts.length ? _dbl(plPcts[i]) : 0,
        cumulativePnl: double.parse(cumulative.toStringAsFixed(2)),
      ));
    }
    var total = double.parse(cumulative.toStringAsFixed(2));
    if (points.length > 1 && points.every((p) => p.profitLoss == 0)) {
      final base = points.first.equity;
      for (var i = 0; i < points.length; i++) {
        final cum = double.parse((points[i].equity - base).toStringAsFixed(2));
        points[i] = PnlPoint(
          time: points[i].time,
          equity: points[i].equity,
          profitLoss: points[i].profitLoss,
          profitLossPct: points[i].profitLossPct,
          cumulativePnl: cum,
        );
      }
      total = points.last.cumulativePnl;
    }
    return PortfolioHistory(period: periodKey, points: points, totalPnl: total);
  }

  Future<TradeAnalytics> getTradeAnalytics() async {
    final fills = await _fetchAllFills();
    final closed = _analyzeFills(fills);
    final pnls = closed.map((e) => e.$1).toList();
    final holds = closed.map((e) => e.$2).toList();
    final wins = pnls.where((p) => p > 0).toList();
    final losses = pnls.where((p) => p < 0).toList();
    final winRate = closed.isEmpty ? 0.0 : wins.length / closed.length * 100;
    final avgWin = wins.isEmpty ? 0.0 : wins.reduce((a, b) => a + b) / wins.length;
    final avgLoss = losses.isEmpty ? 0.0 : losses.map((e) => e.abs()).reduce((a, b) => a + b) / losses.length;
    final profitFactor = avgLoss > 0
        ? avgWin / avgLoss
        : (avgWin > 0 ? 0.0 : 0.0);
    final history = await getPortfolioHistory('1y');
    final byDatePl = <String, double>{};
    final byDateEq = <String, List<double>>{};
    for (final p in history.points) {
      final d = DateTime.fromMillisecondsSinceEpoch(p.time * 1000, isUtc: true);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDatePl[key] = (byDatePl[key] ?? 0) + p.profitLoss;
      byDateEq.putIfAbsent(key, () => []).add(p.equity);
    }
    final daily = <DailyPnl>[];
    for (final e in byDateEq.entries) {
      var pl = byDatePl[e.key] ?? 0;
      if (pl == 0 && e.value.length > 1) pl = e.value.last - e.value.first;
      daily.add(DailyPnl(date: e.key, pnl: double.parse(pl.toStringAsFixed(2))));
    }
    daily.sort((a, b) => a.date.compareTo(b.date));
    final dayPnls = daily.map((d) => d.pnl).toList();
    return TradeAnalytics(
      totalTrades: closed.length,
      winTrades: wins.length,
      lossTrades: losses.length,
      winRate: double.parse(winRate.toStringAsFixed(1)),
      profitFactor: double.parse(profitFactor.toStringAsFixed(2)),
      avgWin: double.parse(avgWin.toStringAsFixed(2)),
      avgLoss: double.parse(avgLoss.toStringAsFixed(2)),
      avgHoldHours: holds.isEmpty
          ? 0
          : double.parse((holds.reduce((a, b) => a + b) / holds.length).toStringAsFixed(1)),
      totalRealizedPnl: double.parse(pnls.fold(0.0, (a, b) => a + b).toStringAsFixed(2)),
      bestDayPnl: dayPnls.isEmpty ? 0 : dayPnls.reduce((a, b) => a > b ? a : b),
      worstDayPnl: dayPnls.isEmpty ? 0 : dayPnls.reduce((a, b) => a < b ? a : b),
      dailyPnl: daily,
    );
  }

  // --- internals ---

  Future<List<Map<String, dynamic>>> _fetchPositionRows() async {
    final rows = await _client.tradingGet('/v2/positions');
    if (rows is! List) return [];
    return rows.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? _rowForSymbol(List<Map<String, dynamic>> rows, String sym) {
    for (final r in rows) {
      if ((r['symbol'] as String? ?? '').toUpperCase() == sym) return r;
    }
    return null;
  }

  List<Position> _rowsToPositions(List<Map<String, dynamic>> rows) {
    return rows.map((p) {
      final qtyRaw = _dbl(p['qty']);
      final qty = qtyRaw.abs();
      return Position(
        symbol: p['symbol'] as String,
        qty: qty,
        avgCost: _dbl(p['avg_entry_price']),
        price: _dbl(p['current_price']),
        pnl: _dbl(p['unrealized_pl']),
        pnlPct: _dbl(p['unrealized_plpc']) * 100,
        side: qtyRaw < 0 ? 'short' : 'long',
      );
    }).toList();
  }

  OrderModel _orderFromJson(Map<String, dynamic> o) => OrderModel(
        id: o['id'] as String,
        symbol: o['symbol'] as String,
        side: o['side'] as String,
        qty: _dbl(o['qty']),
        type: o['type'] as String,
        status: o['status'] as String,
        filledAvgPrice: o['filled_avg_price'] != null ? _dbl(o['filled_avg_price']) : null,
        submittedAt: o['submitted_at'] as String?,
      );

  bool _isWorthlessRow(Map<String, dynamic> row) {
    final sym = (row['symbol'] as String? ?? '').toUpperCase();
    if (!_occRe.hasMatch(sym)) return false;
    final price = _dbl(row['current_price']);
    final mv = (row['market_value'] as num?)?.abs().toDouble() ?? 0;
    return price <= 0.01 && mv <= 1.0;
  }

  Future<String> _tryCloseIlliquidOption(Map<String, dynamic> row) async {
    final sym = (row['symbol'] as String).toUpperCase();
    final encoded = Uri.encodeComponent(sym);
    try {
      await _client.tradingDelete('/v2/positions/$encoded');
      return 'liquidated';
    } catch (_) {}
    final qty = (row['qty'] as num).abs();
    final qtyStr = qty == qty.roundToDouble() ? '${qty.toInt()}' : '$qty';
    final side = (row['qty'] as num).toDouble() > 0 ? 'sell' : 'buy';
    try {
      await _client.tradingPost('/v2/orders', body: {
        'symbol': sym,
        'qty': qtyStr,
        'side': side,
        'type': 'market',
        'time_in_force': 'day',
      });
      return 'market';
    } catch (_) {}
    try {
      await _client.tradingPost('/v2/orders', body: {
        'symbol': sym,
        'qty': qtyStr,
        'side': side,
        'type': 'limit',
        'limit_price': '0.01',
        'time_in_force': 'day',
      });
      return 'penny_limit';
    } catch (_) {}
    return 'failed';
  }

  Future<Quote> _optionQuote(String occ) async {
    final data = await _client.dataGet(
      '/v1beta1/options/snapshots?symbols=$occ&feed=${creds.optionFeed}',
    ) as Map<String, dynamic>;
    final snap = _optionSnapshotFromResponse(data, occ);
    final q = _parseOptionSnapshot(occ, snap);
    _quoteBaseline[occ] = q;
    return q;
  }

  Future<Quote> _optionQuoteLive(String occ) async {
    try {
      final results = await Future.wait<Object?>([
        _client.dataGet('/v1beta1/options/trades/latest?symbols=$occ&feed=${creds.optionFeed}'),
        _client.dataGet('/v1beta1/options/quotes/latest?symbols=$occ&feed=${creds.optionFeed}'),
      ]);
      final tradeRoot = results[0] as Map<String, dynamic>? ?? {};
      final quoteRoot = results[1] as Map<String, dynamic>? ?? {};
      final trade = _optionLatestRow(tradeRoot, occ, 'trades');
      final lq = _optionLatestRow(quoteRoot, occ, 'quotes');
      final q = _mergeLiveOptionQuote(occ, trade, lq);
      _quoteBaseline[occ] = q;
      return q;
    } catch (_) {
      return _optionQuote(occ);
    }
  }

  Map<String, dynamic> _optionLatestRow(
    Map<String, dynamic> root,
    String occ,
    String key,
  ) {
    final bucket = root[key] as Map<String, dynamic>? ?? {};
    return bucket[occ] as Map<String, dynamic>? ??
        (bucket.isNotEmpty ? bucket.values.first as Map<String, dynamic>? ?? {} : {});
  }

  Quote _mergeLiveStockQuote(
    String sym,
    Map<String, dynamic> trade,
    Map<String, dynamic> lq,
  ) {
    var bid = _dbl(lq['bp']);
    var ask = _dbl(lq['ap']);
    final bidSize = _dbl(lq['bs']);
    final askSize = _dbl(lq['as']);
    var price = _dbl(trade['p']);
    if (price == 0 && ask > 0 && bid > 0) price = (bid + ask) / 2;
    if (price == 0) price = ask;
    if (price == 0) price = bid;
    if (bid <= 0 && ask <= 0 && price > 0) {
      final tick = _tickSize(price);
      bid = price - tick;
      ask = price + tick;
    }
    final base = _quoteBaseline[sym];
    final prevClose = base?.prevClose ?? price;
    final change = price - prevClose;
    return Quote(
      symbol: sym,
      name: base?.name ?? sym,
      price: _roundPrice(price),
      change: _roundPrice(change),
      changePct: prevClose != 0 ? double.parse((change / prevClose * 100).toStringAsFixed(2)) : 0,
      prevClose: _roundPrice(prevClose),
      bid: _roundPrice(bid),
      ask: _roundPrice(ask),
      bidSize: bidSize,
      askSize: askSize,
    );
  }

  Quote _mergeLiveOptionQuote(
    String occ,
    Map<String, dynamic> trade,
    Map<String, dynamic> lq,
  ) {
    var bid = _dbl(lq['bp']);
    var ask = _dbl(lq['ap']);
    var price = _dbl(trade['p']);
    if (price == 0 && ask > 0 && bid > 0) price = (bid + ask) / 2;
    if (price == 0) price = ask;
    if (price == 0) price = bid;
    if (bid <= 0 && ask <= 0 && price > 0) {
      final tick = _tickSize(price);
      bid = price - tick;
      ask = price + tick;
    }
    return Quote(
      symbol: occ,
      name: occ,
      price: _roundPrice(price),
      change: 0,
      changePct: 0,
      prevClose: _roundPrice(price),
      bid: _roundPrice(bid),
      ask: _roundPrice(ask),
      bidSize: _dbl(lq['bs']),
      askSize: _dbl(lq['as']),
    );
  }

  Quote _parseStockSnapshot(String sym, Map<String, dynamic> snap) {
    final daily = snap['dailyBar'] as Map<String, dynamic>? ?? {};
    final prev = snap['prevDailyBar'] as Map<String, dynamic>? ?? {};
    final trade = snap['latestTrade'] as Map<String, dynamic>? ?? {};
    final minute = snap['minuteBar'] as Map<String, dynamic>? ?? {};
    final lq = snap['latestQuote'] as Map<String, dynamic>? ?? {};
    var bid = _dbl(lq['bp']);
    var ask = _dbl(lq['ap']);
    final bidSize = _dbl(lq['bs']);
    final askSize = _dbl(lq['as']);
    var price = _dbl(trade['p']);
    if (price == 0) price = _dbl(lq['ap']);
    if (price == 0) price = _dbl(lq['bp']);
    if (price == 0) price = _dbl(minute['c']);
    if (price == 0) price = _dbl(daily['c']);
    if (price == 0) price = _dbl(prev['c']);
    if (bid <= 0 && ask <= 0 && price > 0) {
      final tick = _tickSize(price);
      bid = price - tick;
      ask = price + tick;
    }
    final prevCloseRaw = _dbl(prev['c'] ?? daily['o']);
    final prevClose = prevCloseRaw == 0 ? price : prevCloseRaw;
    final change = price - prevClose;
    return Quote(
      symbol: sym,
      name: sym,
      price: _roundPrice(price),
      change: _roundPrice(change),
      changePct: prevClose != 0 ? double.parse((change / prevClose * 100).toStringAsFixed(2)) : 0,
      prevClose: _roundPrice(prevClose),
      bid: _roundPrice(bid),
      ask: _roundPrice(ask),
      bidSize: bidSize,
      askSize: askSize,
    );
  }

  Quote _parseOptionSnapshot(String occ, Map<String, dynamic> snap) {
    final trade = snap['latestTrade'] as Map<String, dynamic>? ?? {};
    final lq = snap['latestQuote'] as Map<String, dynamic>? ?? {};
    var bid = _dbl(lq['bp']);
    var ask = _dbl(lq['ap']);
    var price = _dbl(trade['p']);
    if (price == 0) price = ask;
    if (price == 0) price = bid;
    if (bid <= 0 && ask <= 0 && price > 0) {
      final tick = _tickSize(price);
      bid = price - tick;
      ask = price + tick;
    }
    return Quote(
      symbol: occ,
      name: occ,
      price: _roundPrice(price),
      change: 0,
      changePct: 0,
      prevClose: _roundPrice(price),
      bid: _roundPrice(bid),
      ask: _roundPrice(ask),
      bidSize: _dbl(lq['bs']),
      askSize: _dbl(lq['as']),
    );
  }

  OrderBook _orderBookFromQuote(Quote q, String sym) {
    final asks = <OrderBookLevel>[
      OrderBookLevel(
        price: q.ask,
        size: q.askSize,
        isReal: q.ask > 0,
      ),
    ];
    final bids = <OrderBookLevel>[
      OrderBookLevel(
        price: q.bid,
        size: q.bidSize,
        isReal: q.bid > 0,
      ),
    ];
    while (asks.length < _depthLevels) {
      asks.add(OrderBookLevel(price: 0, size: 0, isReal: false));
    }
    while (bids.length < _depthLevels) {
      bids.add(OrderBookLevel(price: 0, size: 0, isReal: false));
    }
    return OrderBook(symbol: sym, asks: asks, bids: bids);
  }

  OrderBook _trimBookLevels(OrderBook book, int levels) {
    return OrderBook(
      symbol: book.symbol,
      asks: book.asks.take(levels).toList(),
      bids: book.bids.take(levels).toList(),
    );
  }

  Future<OrderBook> _mergeCustomDepth(OrderBook base, String sym) async {
    final tpl = depthApiUrl.trim();
    if (tpl.isEmpty) return base;
    try {
      final url = tpl.replaceAll('{symbol}', sym);
      final resp = await _external.get<Map<String, dynamic>>(url);
      final data = resp.data;
      if (data == null) return base;

      final apiAsks = _levelsFromJsonList(data['asks']);
      final apiBids = _levelsFromJsonList(data['bids']);
      if (apiAsks.isEmpty && apiBids.isEmpty) return base;

      final asks = List<OrderBookLevel>.from(base.asks);
      final bids = List<OrderBookLevel>.from(base.bids);
      for (var i = 0; i < _depthLevels; i++) {
        if (i < apiAsks.length) asks[i] = apiAsks[i];
        if (i < apiBids.length) bids[i] = apiBids[i];
      }
      return OrderBook(symbol: sym, asks: asks, bids: bids);
    } catch (_) {
      return base;
    }
  }

  List<OrderBookLevel> _levelsFromJsonList(Object? raw) {
    if (raw is! List) return const [];
    final out = <OrderBookLevel>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final price = _dbl(m['price'] ?? m['p']);
      final size = _dbl(m['size'] ?? m['s']);
      if (price <= 0) continue;
      out.add(OrderBookLevel(price: _roundPrice(price), size: size, isReal: true));
      if (out.length >= _depthLevels) break;
    }
    return out;
  }

  List<Bar> _parseBars(List<dynamic> raw) {
    final bars = <Bar>[];
    for (final b in raw) {
      final m = b as Map<String, dynamic>;
      final o = m['o'];
      final c = m['c'];
      if (o == null || c == null) continue;
      final open = _dbl(o);
      final close = _dbl(c);
      final hi = m['h'] != null ? _dbl(m['h']) : [open, close].reduce((a, b) => a > b ? a : b);
      final lo = m['l'] != null ? _dbl(m['l']) : [open, close].reduce((a, b) => a < b ? a : b);
      bars.add(Bar(
        time: _barTimeSec(m),
        open: open,
        high: hi,
        low: lo,
        close: close,
      ));
    }
    return bars;
  }

  int _barTimeSec(Map<String, dynamic> m) {
    final t = m['t'];
    if (t is num) {
      final v = t.toInt();
      return v > 10000000000 ? v ~/ 1000 : v;
    }
    if (t is String && t.isNotEmpty) {
      return DateTime.parse(t.replaceFirst('Z', '+00:00')).millisecondsSinceEpoch ~/ 1000;
    }
    return 0;
  }

  List<Bar> _resampleBars(List<Bar> bars, int factor) {
    if (factor <= 1 || bars.isEmpty) return bars;
    final out = <Bar>[];
    for (var i = 0; i < bars.length; i += factor) {
      final chunk = bars.sublist(i, (i + factor).clamp(0, bars.length));
      if (chunk.isEmpty) break;
      out.add(Bar(
        time: chunk.first.time,
        open: chunk.first.open,
        high: chunk.map((b) => b.high).reduce((a, b) => a > b ? a : b),
        low: chunk.map((b) => b.low).reduce((a, b) => a < b ? a : b),
        close: chunk.last.close,
      ));
    }
    return out;
  }

  Future<List<Bar>> _optionBars(String occ, String timeframe) async {
    final spec = _tfMap[timeframe] ?? _tfMap['1D']!;
    final start = DateTime.now().toUtc().subtract(Duration(days: spec.days));
    final startStr = '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    final data = await _client.dataGet(
      '/v1beta1/options/bars?symbols=$occ&timeframe=${spec.alpaca}&start=$startStr&limit=${spec.limit}',
    ) as Map<String, dynamic>;
    final raw = (data['bars'] as Map<String, dynamic>?)?[occ] as List<dynamic>? ?? [];
    return _resampleBars(_parseBars(raw), spec.resample);
  }

  Future<List<Map<String, dynamic>>> _loadAssets() async {
    if (_assetsCache != null) return _assetsCache!;
    final data = await _client.tradingGet('/v2/assets?status=active&asset_class=us_equity');
    _assetsCache = data is List ? data.cast<Map<String, dynamic>>() : [];
    return _assetsCache!;
  }

  Future<List<Map<String, dynamic>>> _fetchAllContracts(String sym) async {
    final today = DateTime.now().toUtc();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final all = <Map<String, dynamic>>[];
    String? pageToken;
    while (true) {
      var path = '/v2/options/contracts?underlying_symbols=$sym&status=active'
          '&expiration_date_gte=$todayStr&limit=1000';
      if (pageToken != null) path += '&page_token=$pageToken';
      final data = await _client.tradingGet(path) as Map<String, dynamic>;
      final batch = data['option_contracts'] as List<dynamic>? ?? [];
      all.addAll(batch.cast<Map<String, dynamic>>());
      pageToken = data['next_page_token'] as String?;
      if (pageToken == null || pageToken.isEmpty) break;
    }
    return all;
  }

  (double, double) _spotStrikeBand(double spot) {
    final band = spot > 150 ? (spot * 0.12).clamp(12.0, double.infinity) : (spot * 0.12).clamp(6.0, double.infinity);
    return (
      double.parse((spot - band).clamp(0.01, double.infinity).toStringAsFixed(2)),
      double.parse((spot + band).toStringAsFixed(2)),
    );
  }

  List<OptionRow> _parseSnapshotChain(Map<String, dynamic> snapshots) {
    final byStrike = SplayTreeMap<double, Map<String, dynamic>>();
    for (final entry in snapshots.entries) {
      final occ = entry.key;
      final m = _occRe.firstMatch(occ);
      if (m == null) continue;
      final strike = int.parse(m.group(4)!) / 1000;
      final row = byStrike.putIfAbsent(strike, () => {'strike': strike});
      final snap = entry.value as Map<String, dynamic>;
      final quote = snap['latestQuote'] as Map<String, dynamic>? ?? {};
      final trade = snap['latestTrade'] as Map<String, dynamic>? ?? {};
      final bid = quote['bp'];
      final ask = quote['ap'];
      final last = trade['p'] ?? ask ?? bid;
      final isCall = m.group(3) == 'C';
      if (isCall) {
        row['call_bid'] = bid != null ? (bid as num).toDouble() : null;
        row['call_ask'] = ask != null ? (ask as num).toDouble() : null;
        row['call_last'] = last != null ? (last as num).toDouble() : null;
        row['call_occ'] = occ;
      } else {
        row['put_bid'] = bid != null ? (bid as num).toDouble() : null;
        row['put_ask'] = ask != null ? (ask as num).toDouble() : null;
        row['put_last'] = last != null ? (last as num).toDouble() : null;
        row['put_occ'] = occ;
      }
    }
    return byStrike.values
        .map((r) => OptionRow(
              strike: r['strike'] as double,
              callBid: r['call_bid'] as double?,
              callAsk: r['call_ask'] as double?,
              callLast: r['call_last'] as double?,
              callOcc: r['call_occ'] as String?,
              putBid: r['put_bid'] as double?,
              putAsk: r['put_ask'] as double?,
              putLast: r['put_last'] as double?,
              putOcc: r['put_occ'] as String?,
            ))
        .toList();
  }

  Future<List<OptionRow>> _chainFromContracts(String sym, String exp, double spot) async {
    final band = _spotStrikeBand(spot);
    final contracts = await _fetchAllContracts(sym);
    final byStrike = SplayTreeMap<double, Map<String, dynamic>>();
    for (final c in contracts) {
      if (c['expiration_date'] != exp) continue;
      final strike = _dbl(c['strike_price']);
      if (strike < band.$1 || strike > band.$2) continue;
      final row = byStrike.putIfAbsent(strike, () => {'strike': strike});
      final occ = c['symbol'] as String? ?? '';
      final t = (c['type'] as String? ?? '').toLowerCase();
      if (t == 'call') {
        row['call_occ'] = occ;
      } else if (t == 'put') {
        row['put_occ'] = occ;
      }
    }
    return byStrike.values
        .map((r) => OptionRow(
              strike: r['strike'] as double,
              callOcc: r['call_occ'] as String?,
              putOcc: r['put_occ'] as String?,
            ))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchAllFills() async {
    final all = <Map<String, dynamic>>[];
    String? pageToken;
    for (var i = 0; i < 15; i++) {
      var path = '/v2/account/activities?activity_types=FILL&direction=asc&page_size=100';
      if (pageToken != null) path += '&page_token=$pageToken';
      final rows = await _client.tradingGet(path);
      if (rows is! List || rows.isEmpty) break;
      all.addAll(rows.cast<Map<String, dynamic>>());
      if (rows.length < 100) break;
      pageToken = rows.last['id'] as String?;
      if (pageToken == null) break;
    }
    return all;
  }

  List<(double pnl, double holdHours)> _analyzeFills(List<Map<String, dynamic>> fills) {
    final legs = <String, Map<String, dynamic>>{};
    for (final f in fills) {
      final oid = '${f['order_id'] ?? f['id'] ?? ''}';
      if (oid.isEmpty) continue;
      final sym = (f['symbol'] as String? ?? '').toUpperCase();
      final side = (f['side'] as String? ?? '').toLowerCase();
      final qty = _dbl(f['qty']);
      final price = _dbl(f['price']);
      final rawT = f['transaction_time'] as String?;
      if (sym.isEmpty || qty <= 0 || price <= 0 || rawT == null) continue;
      if (side != 'buy' && side != 'sell') continue;
      final t = DateTime.parse(rawT.replaceFirst('Z', '+00:00'));
      final leg = legs[oid];
      if (leg == null) {
        legs[oid] = {'symbol': sym, 'side': side, 'qty': qty, 'notional': qty * price, 'time': t};
      } else {
        leg['qty'] = (leg['qty'] as double) + qty;
        leg['notional'] = (leg['notional'] as double) + qty * price;
        if (t.isBefore(leg['time'] as DateTime)) leg['time'] = t;
      }
    }
    final orders = legs.values
        .where((l) => (l['qty'] as double) > 0)
        .map((l) => {
              'symbol': l['symbol'],
              'side': l['side'],
              'qty': l['qty'],
              'price': (l['notional'] as double) / (l['qty'] as double),
              'time': l['time'],
            })
        .toList()
      ..sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    final bySym = <String, List<Map<String, dynamic>>>{};
    for (final o in orders) {
      bySym.putIfAbsent(o['symbol'] as String, () => []).add(o);
    }
    final closed = <(double, double)>[];
    for (final symLegs in bySym.values) {
      closed.addAll(_processSymbolLegs(symLegs));
    }
    return closed;
  }

  List<(double, double)> _processSymbolLegs(List<Map<String, dynamic>> legs) {
    final closed = <(double, double)>[];
    var qty = 0.0;
    var avgCost = 0.0;
    DateTime? openTime;
    var roundPnl = 0.0;

    void closeRound(DateTime end) {
      if (openTime == null) return;
      final holdH = end.difference(openTime!).inSeconds / 3600.0;
      closed.add((double.parse(roundPnl.toStringAsFixed(2)), holdH < 0 ? 0 : holdH));
      openTime = null;
      roundPnl = 0;
    }

    for (final leg in legs) {
      final side = leg['side'] as String;
      var remaining = leg['qty'] as double;
      final price = leg['price'] as double;
      final t = leg['time'] as DateTime;

      if (side == 'buy') {
        while (remaining > 1e-9) {
          if (qty < 0) {
            final cover = remaining < qty.abs() ? remaining : qty.abs();
            roundPnl += (avgCost - price) * cover;
            qty += cover;
            remaining -= cover;
            if (qty.abs() < 1e-9) {
              qty = 0;
              closeRound(t);
            }
          }
          if (remaining <= 1e-9) break;
          if (qty == 0) {
            openTime = t;
            roundPnl = 0;
          }
          final newQty = qty + remaining;
          avgCost = (avgCost * qty + price * remaining) / newQty;
          qty = newQty;
          remaining = 0;
        }
      } else {
        if (qty <= 1e-9) continue;
        final sell = remaining < qty ? remaining : qty;
        roundPnl += (price - avgCost) * sell;
        qty -= sell;
        if (qty.abs() < 1e-9) {
          qty = 0;
          closeRound(t);
        }
      }
    }
    return closed;
  }

  Map<String, dynamic> _stockSnapshotsFromResponse(Map<String, dynamic> data) {
    final nested = data['snapshots'];
    if (nested is Map<String, dynamic> && nested.isNotEmpty) {
      return nested;
    }
    final flat = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key == 'snapshots' || entry.key == 'next_page_token') continue;
      final value = entry.value;
      if (value is Map<String, dynamic> && _looksLikeStockSnapshot(value)) {
        flat[entry.key] = value;
      }
    }
    return flat;
  }

  Map<String, dynamic> _optionSnapshotFromResponse(Map<String, dynamic> data, String occ) {
    final nested = data['snapshots'];
    if (nested is Map<String, dynamic>) {
      final snap = nested[occ];
      if (snap is Map<String, dynamic>) return snap;
    }
    final direct = data[occ];
    if (direct is Map<String, dynamic>) return direct;
    if (_looksLikeOptionSnapshot(data)) return data;
    return const {};
  }

  bool _looksLikeStockSnapshot(Map<String, dynamic> snap) =>
      snap.containsKey('latestTrade') ||
      snap.containsKey('latestQuote') ||
      snap.containsKey('dailyBar') ||
      snap.containsKey('prevDailyBar');

  bool _looksLikeOptionSnapshot(Map<String, dynamic> snap) =>
      snap.containsKey('latestTrade') || snap.containsKey('latestQuote');

  double _dbl(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.split('.').first.trim()) ?? 0;
    return 0;
  }

  double _roundPrice(double v) {
    if (v > 0 && v < 1) return double.parse(v.toStringAsFixed(4));
    return double.parse(v.toStringAsFixed(2));
  }

  double _tickSize(double price) {
    if (price >= 1000) return 1;
    if (price >= 100) return 0.1;
    if (price >= 10) return 0.05;
    return 0.01;
  }
}
