import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_ui.dart';
import '../models/models.dart';
import 'api_service.dart';

final quoteStreamProvider = StreamProvider.family<Quote, String>((ref, symbol) {
  final ws = ref.watch(wsServiceProvider);
  return ws.quotesFor(symbol);
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
  Timer? _timer;
  final _quoteControllers = <String, StreamController<Quote>>{};
  final _latest = <String, Quote>{};
  final _positionsController = StreamController<List<Position>>.broadcast();
  final _accountController = StreamController<AccountSummary>.broadcast();
  final _symbols = <String>{};
  List<Position> _latestPositions = [];
  AccountSummary? _latestAccount;
  bool _portfolioSubscribed = false;

  Stream<List<Position>> get positionsStream => _positionsController.stream;
  Stream<AccountSummary> get accountStream => _accountController.stream;
  List<Position> get latestPositions => _latestPositions;
  AccountSummary? get latestAccount => _latestAccount;

  void connect() => _ensurePolling();

  void _ensurePolling() {
    if (_timer != null) return;
    _timer = Timer.periodic(
      Duration(milliseconds: PlatformUi.isMobile ? 400 : 300),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    if (!_api.isConfigured) return;
    if (_symbols.isNotEmpty) {
      try {
        final quotes = await _api.getQuotes(_symbols.toList());
        quotes.forEach((sym, q) {
          _latest[sym] = q;
          _quoteControllers[sym]?.add(q);
        });
      } catch (_) {}
    }
    if (_portfolioSubscribed) {
      try {
        final positions = await _api.getPositions();
        final account = await _api.getAccount();
        _latestPositions = positions;
        _latestAccount = account;
        _positionsController.add(positions);
        _accountController.add(account);
      } catch (_) {}
    }
  }

  void subscribe(List<String> symbols) {
    connect();
    for (final s in symbols) {
      final sym = s.toUpperCase();
      _symbols.add(sym);
      _quoteControllers.putIfAbsent(sym, () => StreamController<Quote>.broadcast());
      if (_latest.containsKey(sym)) {
        _quoteControllers[sym]!.add(_latest[sym]!);
      }
    }
    _poll();
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
    _poll();
  }

  Stream<Quote> quotesFor(String symbol) {
    final sym = symbol.toUpperCase();
    _quoteControllers.putIfAbsent(sym, () => StreamController<Quote>.broadcast());
    subscribe([sym]);
    return _quoteControllers[sym]!.stream;
  }

  void dispose() {
    _timer?.cancel();
    for (final c in _quoteControllers.values) {
      c.close();
    }
    _positionsController.close();
    _accountController.close();
  }
}
