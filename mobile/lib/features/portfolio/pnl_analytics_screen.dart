import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/portfolio_providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/okx_ui.dart';

class PnlAnalyticsScreen extends ConsumerStatefulWidget {
  const PnlAnalyticsScreen({super.key});

  @override
  ConsumerState<PnlAnalyticsScreen> createState() => _PnlAnalyticsScreenState();
}

class _PnlAnalyticsScreenState extends ConsumerState<PnlAnalyticsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Map<String, double> _pnlMap(List<DailyPnl> daily) {
    return {for (final d in daily) d.date: d.pnl};
  }

  String _formatHold(double hours) {
    if (hours <= 0) return '-';
    if (hours < 24) return '${hours.toStringAsFixed(1)} ${S.hours}';
    return '${(hours / 24).toStringAsFixed(1)} ${S.days}';
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(tradeAnalyticsProvider);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(S.tradeAnalytics)),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => ApiErrorView(
          onRetry: () => ref.invalidate(tradeAnalyticsProvider),
          detail: '$e',
        ),
        data: (a) {
          final pnlByDate = _pnlMap(a.dailyPnl);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(tradeAnalyticsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    AnalyticsStatCard(
                      label: S.winRate,
                      value: '${a.winRate.toStringAsFixed(1)}%',
                      valueColor: a.winRate >= 50 ? AppColors.green : AppColors.red,
                    ),
                    AnalyticsStatCard(
                      label: S.profitFactor,
                      value: a.profitFactor > 0 ? '${a.profitFactor.toStringAsFixed(2)}:1' : '-',
                      valueColor: a.profitFactor >= 1 ? AppColors.green : AppColors.red,
                    ),
                    AnalyticsStatCard(
                      label: S.avgHoldTime,
                      value: _formatHold(a.avgHoldHours),
                    ),
                    AnalyticsStatCard(
                      label: S.totalTrades,
                      value: '${a.totalTrades}',
                    ),
                    AnalyticsStatCard(
                      label: S.realizedPnl,
                      value: money.format(a.totalRealizedPnl),
                      valueColor: pnlColor(a.totalRealizedPnl),
                    ),
                    AnalyticsStatCard(
                      label: '${S.avgWin} / ${S.avgLoss}',
                      value: '${money.format(a.avgWin)} / ${money.format(a.avgLoss)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AnalyticsStatCard(
                        label: S.bestDay,
                        value: money.format(a.bestDayPnl),
                        valueColor: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnalyticsStatCard(
                        label: S.worstDay,
                        value: money.format(a.worstDayPnl),
                        valueColor: AppColors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  S.winRateOpens(a.totalTrades, a.winTrades, a.lossTrades),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 20),
                _PnlCalendar(
                  month: _month,
                  pnlByDate: pnlByDate,
                  onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PnlCalendar extends StatelessWidget {
  const _PnlCalendar({
    required this.month,
    required this.pnlByDate,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final Map<String, double> pnlByDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('yyyy年 M月').format(month);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[
      for (final w in ['日', '一', '二', '三', '四', '五', '六'])
        Center(child: Text(w, style: TextStyle(color: AppColors.muted, fontSize: 11))),
    ];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final pnl = pnlByDate[key];
      cells.add(_DayCell(day: day, pnl: pnl));
    }

    return OkxPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: onPrev,
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    S.pnlCalendar,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: onNext,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
          ],
        ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, this.pnl});

  final int day;
  final double? pnl;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    if (pnl != null && pnl != 0) {
      bg = pnl! > 0
          ? AppColors.green.withValues(alpha: 0.15 + (pnl!.abs().clamp(0, 500) / 500 * 0.35))
          : AppColors.red.withValues(alpha: 0.15 + (pnl!.abs().clamp(0, 500) / 500 * 0.35));
    }
    return Container(
      decoration: BoxDecoration(
        color: bg ?? AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          if (pnl != null && pnl != 0)
            Text(
              pnl!.abs() >= 100 ? pnl!.toStringAsFixed(0) : pnl!.toStringAsFixed(1),
              style: TextStyle(fontSize: 8, color: pnlColor(pnl!)),
            ),
        ],
      ),
    );
  }
}
