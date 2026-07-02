import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/symbol_utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';

/// Bump to force one-shot HTTP refetch (e.g. after orders).
final portfolioRefreshProvider = StateProvider<int>((ref) => 0);

final positionsProvider = StreamProvider<List<Position>>((ref) async* {
  ref.watch(portfolioRefreshProvider);
  ref.watch(apiServiceProvider);
  if (!ref.watch(alpacaCredentialsProvider).isConfigured) {
    yield const <Position>[];
    return;
  }
  final ws = ref.watch(wsServiceProvider);
  ws.subscribePortfolio(force: true);
  try {
    yield withoutExpiredOptions(await ref.read(apiServiceProvider).getPositions());
  } catch (_) {
    yield const <Position>[];
  }
  await for (final rows in ws.positionsStream) {
    yield withoutExpiredOptions(rows);
  }
});

final accountProvider = StreamProvider<AccountSummary?>((ref) async* {
  ref.watch(portfolioRefreshProvider);
  ref.watch(apiServiceProvider);
  if (!ref.watch(alpacaCredentialsProvider).isConfigured) {
    yield null;
    return;
  }
  final ws = ref.watch(wsServiceProvider);
  ws.subscribePortfolio(force: true);
  try {
    yield await ref.read(apiServiceProvider).getAccount();
  } catch (_) {
    yield ws.latestAccount;
  }
  await for (final row in ws.accountStream) {
    yield row;
  }
});

final ordersProvider = FutureProvider<List<OrderModel>>((ref) async {
  ref.watch(portfolioRefreshProvider);
  return ref.read(apiServiceProvider).getOrders();
});

void refreshPortfolio(WidgetRef ref) {
  ref.read(portfolioRefreshProvider.notifier).state++;
  ref.read(wsServiceProvider).subscribePortfolio(force: true);
  ref.invalidate(accountProvider);
  ref.invalidate(positionsProvider);
  ref.invalidate(ordersProvider);
}

final pnlPeriodProvider = StateProvider<String>((ref) => '7d');

final portfolioHistoryProvider = FutureProvider.family<PortfolioHistory, String>((ref, period) async {
  ref.watch(portfolioRefreshProvider);
  return ref.read(apiServiceProvider).getPortfolioHistory(period);
});

final tradeAnalyticsProvider = FutureProvider<TradeAnalytics>((ref) async {
  ref.watch(portfolioRefreshProvider);
  return ref.read(apiServiceProvider).getTradeAnalytics();
});
