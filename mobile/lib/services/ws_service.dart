import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_ui.dart';
import '../core/symbol_utils.dart';
import '../models/models.dart';
import 'alpaca_repository.dart';
import 'api_service.dart';

final quoteStreamProvider = StreamProvider.family<Quote, String>((ref, symbol) {
  final ws = ref.watch(wsServiceProvider);
  return ws.quotesFor(symbol);
});

final orderBookStreamProvider = StreamProvider.family<OrderBook, String>((ref, symbol) {
  final ws = ref.watch(wsServiceProvider);
  return ws.orderBooksFor(symbol);
});

/// Unified quote + order book — header and 五档 always share the same snapshot.
final marketSnapshotStreamProvider = StreamProvider.family<MarketSnapshot, String>((ref, symbol) {
  final ws = ref.watch(wsServiceProvider);
  return ws.snapshotsFor(symbol);
});

final wsServiceProvider = Provider<RealtimeService>((ref) {
  final api = ref.watch(apiServiceProvider);
  final service = RealtimeService(api);
  ref.onDispose(service.dispose);
  return service;
});

/// Polls Alpaca for quotes. Background symbols (home watchlist) and focus symbol (trade) are separate.
class RealtimeService {
  RealtimeService(this._api);

  final ApiService _api;
  Timer? _focusTimer;
  Timer? _batchTimer;
  final _quoteControllers = <String, StreamController<Quote>>{};
  final _bookControllers = <String, StreamController<OrderBook>>{};
  final _snapshotControllers = <String, StreamController<MarketSnapshot>>{};
  final _latestQuotes = <String, Quote>{};
  final _latestBooks = <String, OrderBook>{};
  final _latestSnapshots = <String, MarketSnapshot>{};
  final _positionsController = StreamController<List<Position>>.broadcast();
  final _accountController = StreamController<AccountSummary>.broadcast();
  final _backgroundSymbols = <String>{};
  String? _focusSymbol;
  List<Position> _latestPositions = [];
  AccountSummary? _latestAccount;
  bool _portfolioSubscribed = false;
  bool _portfolioPollInFlight = false;
  bool _batchPollInFlight = false;
  int _batchTick = 0;
  int _focusPollGen = 0;

  static const _focusIntervalMs = 300;
  static const _batchIntervalMs = 2500;
  static const _portfolioEveryNTicks = 3;

  Stream<List<Position>> get positionsStream => _positionsController.stream;
  Stream<AccountSummary> get accountStream => _accountController.stream;
  List<Position> get latestPositions => _latestPositions;
  AccountSummary? get latestAccount => _latestAccount;

  void _ensureControllers(String sym) {
    _quoteControllers.putIfAbsent(sym, () => StreamController<Quote>.broadcast());
    _bookControllers.putIfAbsent(sym, () => StreamController<OrderBook>.broadcast());
    _snapshotControllers.putIfAbsent(sym, () => StreamController<MarketSnapshot>.broadcast());
  }

  void _syncPolling() {
    final needsPoll = _focusSymbol != null || _backgroundSymbols.isNotEmpty || _portfolioSubscribed;
    if (!needsPoll) {
      _focusTimer?.cancel();
      _focusTimer = null;
      _batchTimer?.cancel();
      _batchTimer = null;
      return;
    }
    _focusTimer ??= Timer.periodic(
      Duration(milliseconds: PlatformUi.isMobile ? _focusIntervalMs : 180),
      (_) => _pollFocusMarket(),
    );
    _batchTimer ??= Timer.periodic(
      const Duration(milliseconds: _batchIntervalMs),
      (_) => _pollBatch(),
    );
  }

  /// Home tab: watchlist + position symbols. Replaces previous background set.
  void setBackgroundSymbols(Iterable<String> symbols) {
    _backgroundSymbols
      ..clear()
      ..addAll(symbols.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty));
    for (final sym in _backgroundSymbols) {
      _ensureControllers(sym);
    }
    _syncPolling();
  }

  /// Trade tab: high-frequency refresh for the active symbol only.
  void setFocusSymbol(String? symbol) {
    final sym = symbol?.trim().toUpperCase();
    if (sym == null || sym.isEmpty) {
      _focusSymbol = null;
      _syncPolling();
      return;
    }
    if (_focusSymbol == sym) return;
    _focusSymbol = sym;
    _ensureControllers(sym);
    _syncPolling();
    _pollFocusMarket();
  }

  Future<void> _pollFocusMarket() async {
    final sym = _focusSymbol;
    if (!_api.isConfigured || sym == null) return;
    final gen = ++_focusPollGen;
    try {
      final l1 = await _api.getMarketSnapshot(sym, refresh: true, l1Only: true);
      if (gen != _focusPollGen || sym != _focusSymbol) return;
      _emitSnapshot(sym, l1);

      if (_api.hasCustomDepth) {
        final full = await _api.getMarketSnapshot(sym, refresh: true, l1Only: false);
        if (gen != _focusPollGen || sym != _focusSymbol) return;
        _emitSnapshot(sym, full);
      }
    } catch (_) {}
  }

  Future<void> _pollBatch() async {
    if (!_api.isConfigured || _batchPollInFlight) return;
    _batchPollInFlight = true;
    _batchTick++;
    try {
      final others = _backgroundSymbols.where((s) => s != _focusSymbol).toList();
      if (others.isNotEmpty) {
        final quotes = await _api.getQuotes(others);
        quotes.forEach(_emitQuote);
      }
      if (_portfolioSubscribed && _batchTick % _portfolioEveryNTicks == 0) {
        await _pollPortfolio();
      }
    } catch (_) {}
    _batchPollInFlight = false;
  }

  void _emitSnapshot(String sym, MarketSnapshot snap) {
    _latestSnapshots[sym] = snap;
    _latestQuotes[sym] = snap.quote;
    _latestBooks[sym] = snap.orderBook;
    _snapshotControllers[sym]?.add(snap);
    _quoteControllers[sym]?.add(snap.quote);
    _bookControllers[sym]?.add(snap.orderBook);
  }

  void _emitQuote(String sym, Quote q) {
    _latestQuotes[sym] = q;
    _quoteControllers[sym]?.add(q);
  }

  Future<void> _pollPortfolio() async {
    if (!_api.isConfigured || _portfolioPollInFlight) return;
    _portfolioPollInFlight = true;
    try {
      final results = await Future.wait([
        _api.getPositions(),
        _api.getAccount(),
      ]);
      _latestPositions = results[0] as List<Position>;
      _latestAccount = results[1] as AccountSummary;
      _positionsController.add(_latestPositions);
      _accountController.add(_latestAccount!);
    } catch (_) {}
    _portfolioPollInFlight = false;
  }

  void subscribePortfolio({bool force = false}) {
    _portfolioSubscribed = true;
    _syncPolling();
    if (!force) {
      if (_latestPositions.isNotEmpty) {
        _positionsController.add(_latestPositions);
      }
      if (_latestAccount != null) {
        _accountController.add(_latestAccount!);
      }
      return;
    }
    pollPortfolioNow();
  }

  void pollPortfolioNow() {
    if (!_portfolioSubscribed) _portfolioSubscribed = true;
    _syncPolling();
    unawaited(_pollPortfolio());
  }

  /// Instant UI refresh from order API response; server poll reconciles shortly after.
  void applyOptimisticOrder(OrderModel order) {
    final sym = order.symbol.toUpperCase();
    final delta = order.effectiveQty;
    if (delta <= 0) return;
    final isBuy = order.side.toLowerCase() == 'buy';
    final mark = (order.filledAvgPrice != null && order.filledAvgPrice! > 0)
        ? order.filledAvgPrice!
        : (_latestQuotes[sym]?.price ?? 0);
    final positions = List<Position>.from(_latestPositions);
    final idx = positions.indexWhere((p) => p.symbol.toUpperCase() == sym);

    if (idx < 0) {
      if (isBuy) {
        positions.add(_makePosition(sym, delta, mark, side: 'long'));
      } else {
        positions.add(_makePosition(sym, delta, mark, side: 'short'));
      }
    } else {
      final p = positions[idx];
      final isLong = p.side.toLowerCase() != 'short';
      if (isLong && isBuy) {
        positions[idx] = _mergePosition(p, delta, mark, increasing: true);
      } else if (isLong && !isBuy) {
        final remain = p.qty - delta;
        if (remain <= 1e-6) {
          positions.removeAt(idx);
        } else {
          positions[idx] = _makePosition(sym, remain, mark, side: 'long', avgCost: p.avgCost);
        }
      } else if (!isLong && isBuy) {
        final remain = p.qty - delta;
        if (remain <= 1e-6) {
          positions.removeAt(idx);
        } else {
          positions[idx] = _makePosition(sym, remain, mark, side: 'short', avgCost: p.avgCost);
        }
      } else {
        positions[idx] = _mergePosition(p, delta, mark, increasing: true);
      }
    }

    _latestPositions = positions;
    _positionsController.add(positions);
  }

  Position _makePosition(
    String sym,
    double qty,
    double mark, {
    required String side,
    double? avgCost,
  }) {
    final cost = avgCost ?? mark;
    final mult = isOptionSymbol(sym) ? 100.0 : 1.0;
    final pnl = side == 'short' ? (cost - mark) * qty * mult : (mark - cost) * qty * mult;
    final pct = cost > 0 ? pnl / (cost * qty * mult) * 100 : 0.0;
    return Position(
      symbol: sym,
      qty: qty,
      avgCost: cost,
      price: mark,
      pnl: pnl,
      pnlPct: pct,
      side: side,
    );
  }

  Position _mergePosition(Position p, double addQty, double mark, {required bool increasing}) {
    final newQty = p.qty + addQty;
    final newAvg = (p.avgCost * p.qty + mark * addQty) / newQty;
    return _makePosition(p.symbol, newQty, mark, side: p.side, avgCost: newAvg);
  }

  void setPortfolioActive(bool active) {
    if (active) {
      subscribePortfolio();
      return;
    }
    _portfolioSubscribed = false;
    _syncPolling();
  }

  Stream<Quote> quotesFor(String symbol) {
    final sym = symbol.toUpperCase();
    _ensureControllers(sym);
    final cached = _latestQuotes[sym];
    if (cached != null) {
      scheduleMicrotask(() => _quoteControllers[sym]?.add(cached));
    }
    return _quoteControllers[sym]!.stream;
  }

  Stream<OrderBook> orderBooksFor(String symbol) {
    final sym = symbol.toUpperCase();
    _ensureControllers(sym);
    final cached = _latestBooks[sym];
    if (cached != null) {
      scheduleMicrotask(() => _bookControllers[sym]?.add(cached));
    }
    return _bookControllers[sym]!.stream;
  }

  Stream<MarketSnapshot> snapshotsFor(String symbol) {
    final sym = symbol.toUpperCase();
    _ensureControllers(sym);
    final cached = _latestSnapshots[sym];
    if (cached != null) {
      scheduleMicrotask(() => _snapshotControllers[sym]?.add(cached));
    }
    return _snapshotControllers[sym]!.stream;
  }

  void dispose() {
    _focusTimer?.cancel();
    _batchTimer?.cancel();
    for (final c in _quoteControllers.values) {
      c.close();
    }
    for (final c in _bookControllers.values) {
      c.close();
    }
    for (final c in _snapshotControllers.values) {
      c.close();
    }
    _positionsController.close();
    _accountController.close();
  }
}
