import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/ws_service.dart';
import '../../shared/widgets/okx_ui.dart';

final _priceFmt = NumberFormat('#,##0.00');
final _qtyFmt = NumberFormat('#,##0');
const _levels = 5;

/// Five-level bid / ask depth (五档).
/// Custom depth API configured → user data; otherwise Alpaca L1 only (2–5 dimmed).
class DepthBookPanel extends ConsumerWidget {
  const DepthBookPanel({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(marketSnapshotStreamProvider(symbol)).valueOrNull;
    final book = snap?.orderBook;

    final asks = _padLevels(book?.asks ?? const <OrderBookLevel>[]);
    final bids = _padLevels(book?.bids ?? const <OrderBookLevel>[]);

    return SizedBox(
      height: double.infinity,
      child: OkxPanel(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.depthBook,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: book == null
                  ? Center(
                      child: Text(S.noBidAsk, style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              for (var i = asks.length - 1; i >= 0; i--)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: _DepthRow(
                                      label: _askLabel(i + 1),
                                      level: asks[i],
                                      color: AppColors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              for (var i = 0; i < bids.length; i++)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: _DepthRow(
                                      label: _bidLabel(i + 1),
                                      level: bids[i],
                                      color: AppColors.green,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<OrderBookLevel> _padLevels(List<OrderBookLevel> levels) {
    if (levels.length >= _levels) return levels.take(_levels).toList();
    return [
      ...levels,
      for (var i = levels.length; i < _levels; i++)
        OrderBookLevel(price: 0, size: 0, isReal: false),
    ];
  }

  String _askLabel(int level) => '卖$level';

  String _bidLabel(int level) => '买$level';
}

class _DepthRow extends StatelessWidget {
  const _DepthRow({
    required this.label,
    required this.level,
    required this.color,
  });

  final String label;
  final OrderBookLevel level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dimmed = !level.isReal;
    final opacity = dimmed ? 0.22 : 1.0;
    final price = level.price;
    final size = level.size;

    return Opacity(
      opacity: opacity,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              !dimmed && price > 0 ? _priceFmt.format(price) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: dimmed ? FontWeight.w400 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              !dimmed && size > 0 ? _qtyFmt.format(size) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, color: AppColors.muted2),
            ),
          ),
        ],
      ),
    );
  }
}
