import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_ui.dart';
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

/// Polls Alpaca directly for quotes and portfolio updates (no local backend).
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
  final _symbols = <String>{};
  String? _focusSymbol;
  List<Position> _latestPositions = [];
  AccountSummary? _latestAccount;
  bool _portfolioSubscribed = false;
  bool _batchPollInFlight = false;
  int _batchTick = 0;
  int _focusPollGen = 0;

  static const _focusIntervalMs = 250;
  static const _batchIntervalMs = 1200;

  Stream<List<Position>> get positionsStream => _positionsController.stream;
  Stream<AccountSummary> get accountStream => _accountController.stream;
  List<Position> get latestPositions => _latestPositions;
  AccountSummary? get latestAccount => _latestAccount;

  void connect() => _ensurePolling();

  void _ensurePolling() {
    _focusTimer ??= Timer.periodic(
      Duration(milliseconds: PlatformUi.isMobile ? _focusIntervalMs : 180),
      (_) => _pollFocusMarket(),
    );
    _batchTimer ??= Timer.periodic(
      const Duration(milliseconds: _batchIntervalMs),
      (_) => _pollBatch(),
    );
  }

  void setFocusSymbol(String? symbol) {
    final sym = symbol?.trim().toUpperCase();
    if (sym == null || sym.isEmpty) {
      _focusSymbol = null;
      return;
    }
    if (_focusSymbol == sym) return;
    _focusSymbol = sym;
    subscribe([sym]);
    _pollFocusMarket();
  }

  Future<void> _pollFocusMarket() async {
    final sym = _focusSymbol;
    if (!_api.isConfigured || sym == null) return;
    final gen = ++_focusPollGen;
    try {
      // Always refresh L1 first so 买一/卖一 never stalls on slow custom depth API.
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
      final others = _symbols.where((s) => s != _focusSymbol).toList();
      if (others.isNotEmpty) {
        final quotes = await _api.getQuotes(others);
        quotes.forEach(_emitQuote);
      }
      if (_portfolioSubscribed && _batchTick % 2 == 0) {
        try {
          final positions = await _api.getPositions();
          final account = await _api.getAccount();
          _latestPositions = positions;
          _latestAccount = account;
          _positionsController.add(positions);
          _accountController.add(account);
        } catch (_) {}
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

  void subscribe(List<String> symbols) {
    connect();
    for (final s in symbols) {
      final sym = s.toUpperCase();
      _symbols.add(sym);
      _quoteControllers.putIfAbsent(sym, () => StreamController<Quote>.broadcast());
      _bookControllers.putIfAbsent(sym, () => StreamController<OrderBook>.broadcast());
      _snapshotControllers.putIfAbsent(sym, () => StreamController<MarketSnapshot>.broadcast());
      final snap = _latestSnapshots[sym];
      if (snap != null) {
        _snapshotControllers[sym]!.add(snap);
        _quoteControllers[sym]!.add(snap.quote);
        _bookControllers[sym]!.add(snap.orderBook);
      } else {
        if (_latestQuotes.containsKey(sym)) {
          _quoteControllers[sym]!.add(_latestQuotes[sym]!);
        }
        if (_latestBooks.containsKey(sym)) {
          _bookControllers[sym]!.add(_latestBooks[sym]!);
        }
      }
    }
    if (_focusSymbol != null && symbols.map((e) => e.toUpperCase()).contains(_focusSymbol)) {
      _pollFocusMarket();
    } else {
      _pollBatch();
    }
  }

  void subscribePortfolio({bool force = false}) {
    _portfolioSubscribed = true;
    connect();
    if (!force) {
      if (_latestPositions.isNotEmpty) {
        _positionsController.add(_latestPositions);
      }
      if (_latestAccount != null) {
        _accountController.add(_latestAccount!);
      }
    }
    _pollBatch();
  }

  Stream<Quote> quotesFor(String symbol) {
    final sym = symbol.toUpperCase();
    _quoteControllers.putIfAbsent(sym, () => StreamController<Quote>.broadcast());
    subscribe([sym]);
    return _quoteControllers[sym]!.stream;
  }

  Stream<OrderBook> orderBooksFor(String symbol) {
    final sym = symbol.toUpperCase();
    _bookControllers.putIfAbsent(sym, () => StreamController<OrderBook>.broadcast());
    subscribe([sym]);
    if (sym == _focusSymbol) _pollFocusMarket();
    return _bookControllers[sym]!.stream;
  }

  Stream<MarketSnapshot> snapshotsFor(String symbol) {
    final sym = symbol.toUpperCase();
    _snapshotControllers.putIfAbsent(sym, () => StreamController<MarketSnapshot>.broadcast());
    subscribe([sym]);
    if (sym == _focusSymbol) _pollFocusMarket();
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
