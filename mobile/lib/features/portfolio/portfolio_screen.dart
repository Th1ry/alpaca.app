import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../models/models.dart';
import '../../providers/portfolio_providers.dart';
import '../../shared/widgets/positions_list.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/okx_ui.dart';
import '../../shared/widgets/floating_capsule_nav.dart';
import 'pnl_analytics_screen.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({
    super.key,
    required this.onTapPosition,
    this.isActive = false,
  });

  final void Function(Position position) onTapPosition;
  final bool isActive;

  static List<(String, String)> get _periodOptions => [
    ('7d', S.period7d),
    ('1m', S.period1m),
    ('1y', S.period1y),
  ];

  void _openAnalytics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PnlAnalyticsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountProvider);
    final positionsAsync = ref.watch(positionsProvider);
    final period = ref.watch(pnlPeriodProvider);
    final historyAsync = isActive ? ref.watch(portfolioHistoryProvider(period)) : null;
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final pct = NumberFormat('+#0.00;-#0.00');

    final loading = accountAsync.isLoading || positionsAsync.isLoading;
    if (loading && !accountAsync.hasValue) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final error = accountAsync.error ?? positionsAsync.error;
    if (error != null && !accountAsync.hasValue) {
      return ApiErrorView(
        onRetry: () => refreshPortfolio(ref),
        detail: S.loadFailedHint,
      );
    }

    final account = accountAsync.value;
    final history = historyAsync?.valueOrNull;

    return Stack(
      children: [
        const Positioned.fill(child: GlassAmbientLayer()),
        RefreshIndicator(
      onRefresh: () async {
        refreshPortfolio(ref);
        if (!isActive) return;
        await Future.wait([
          ref.read(accountProvider.future),
          ref.read(positionsProvider.future),
          ref.read(portfolioHistoryProvider(period).future),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + FloatingCapsuleNav.overlayInset(context),
        ),
        children: [
          if (account == null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ApiErrorView(
                onRetry: () => refreshPortfolio(ref),
                detail: S.loadFailedHint,
              ),
            ),
          ] else ...[
            SummaryCard(
              label: S.totalAssets,
              value: money.format(account.equity),
              sub: '${money.format(account.dailyPnl)} (${pct.format(account.dailyPnlPct)}%) ${S.todayPnl}',
              subColor: pnlColor(account.dailyPnl),
              onSubTap: () => _openAnalytics(context),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OkxMiniStat(label: S.buyingPower, value: money.format(account.buyingPower)),
                const SizedBox(width: 10),
                OkxMiniStat(label: S.marginBuyingPower, value: money.format(account.marginBuyingPower)),
              ],
            ),
            const SizedBox(height: 20),
            OkxSectionHeader(
              title: S.pnlCurve,
              trailing: history != null
                  ? Text(
                      money.format(history.totalPnl),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pnlColor(history.totalPnl),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OkxSegmentRow(
                    options: _periodOptions.map((o) => (o.$1, o.$2)).toList(),
                    selected: period,
                    onSelect: (k) => ref.read(pnlPeriodProvider.notifier).state = k,
                  ),
                  const SizedBox(height: 8),
                  if (isActive && historyAsync != null && historyAsync.isLoading && history == null)
                    const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    PnlCurveChart(
                      key: ValueKey(period),
                      points: history?.points ?? const [],
                      totalPnl: history?.totalPnl ?? 0,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          OkxSectionHeader(title: S.positions),
          PositionsList(showHeader: true, onTapPosition: onTapPosition),
        ],
      ),
        ),
      ],
    );
  }
}
