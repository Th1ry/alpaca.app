import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alpaca_config.dart';
import '../models/models.dart';
import '../providers/app_settings_provider.dart';
import 'alpaca_repository.dart';

/// Single source of truth — always mirrors persisted [appSettingsProvider].
final alpacaCredentialsProvider = Provider<AlpacaCredentials>((ref) {
  return ref.watch(appSettingsProvider).alpaca;
});

final alpacaRepositoryProvider = Provider<AlpacaRepository>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return AlpacaRepository(
    ref.watch(alpacaCredentialsProvider),
    depthApiUrl: settings.depthApiUrl,
  );
});

/// Back-compat alias — app code uses [apiServiceProvider].
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(alpacaRepositoryProvider));
});

class ApiService {
  ApiService(this._repo);

  final AlpacaRepository _repo;

  bool get isConfigured => _repo.isConfigured;

  bool get hasCustomDepth => _repo.hasCustomDepth;

  Future<AccountSummary> getAccount() => _repo.getAccount();

  Future<List<Position>> getPositions() => _repo.getPositions();

  Future<List<OrderModel>> getOrders() => _repo.getOrders();

  Future<PortfolioHistory> getPortfolioHistory(String period) =>
      _repo.getPortfolioHistory(period);

  Future<TradeAnalytics> getTradeAnalytics() => _repo.getTradeAnalytics();

  Future<Quote> getQuote(String symbol) => _repo.getQuote(symbol);

  Future<Quote> getQuoteLive(String symbol) => _repo.getQuoteLive(symbol);

  Future<MarketSnapshot> getMarketSnapshot(
    String symbol, {
    bool refresh = false,
    bool l1Only = false,
  }) =>
      _repo.getMarketSnapshot(symbol, refresh: refresh, l1Only: l1Only);

  Future<OrderBook> getOrderBook(String symbol, {int levels = 5}) =>
      _repo.getOrderBook(symbol, levels: levels);

  Future<Map<String, Quote>> getQuotes(List<String> symbols) => _repo.getQuotes(symbols);

  Future<List<Bar>> getBars(String symbol, String timeframe) =>
      _repo.getBars(symbol, timeframe);

  Future<List<Bar>> getSparklineBars(String symbol) => _repo.getSparklineBars(symbol);

  Future<List<Map<String, String>>> search(String q) async {
    final rows = await _repo.searchSymbols(q);
    return rows.map((e) => {'symbol': e.symbol, 'name': e.name}).toList();
  }

  Future<List<SearchResult>> searchSymbols(String q) => _repo.searchSymbols(q);

  Future<List<NewsItem>> getNews({int limit = 15, String? symbols}) =>
      _repo.getNews(limit: limit, symbols: symbols);

  Future<NewsItem?> getNewsById(String id) => _repo.getNewsById(id);

  Future<OptionsChain> getOptionsChain(String symbol, {String? expiry}) =>
      _repo.getOptionsChain(symbol, expiry: expiry);

  Future<OrderModel> submitOrder({
    required String symbol,
    required double qty,
    required String side,
    required String type,
    String timeInForce = 'day',
    double? limitPrice,
  }) =>
      _repo.submitOrder(
        symbol: symbol,
        qty: qty,
        side: side,
        type: type,
        timeInForce: timeInForce,
        limitPrice: limitPrice,
      );

  Future<OrderModel> closePosition(String symbol, double percent, {Position? position}) =>
      _repo.closePosition(symbol, percent, position: position);

  Future<void> dismissPosition(String symbol) => _repo.dismissPosition(symbol);

  Future<List<OrderModel>> setPositionBracket({
    required String symbol,
    double? takeProfitPrice,
    double? stopLossPrice,
    Position? position,
  }) =>
      _repo.setPositionBracket(
        symbol: symbol,
        takeProfitPrice: takeProfitPrice,
        stopLossPrice: stopLossPrice,
        position: position,
      );
}
