import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/okx_ui.dart';

final _priceFmt = NumberFormat('#,##0.00');
final _qtyFmt = NumberFormat('#,##0');

/// Five-level bid / ask depth (五档).
class DepthBookPanel extends ConsumerStatefulWidget {
  const DepthBookPanel({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<DepthBookPanel> createState() => _DepthBookPanelState();
}

class _DepthBookPanelState extends ConsumerState<DepthBookPanel> {
  OrderBook? _book;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant DepthBookPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!ref.read(apiServiceProvider).isConfigured) return;
    try {
      final book = await ref.read(apiServiceProvider).getOrderBook(widget.symbol, levels: 5);
      if (mounted) setState(() => _book = book);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final asks = book?.asks ?? const <OrderBookLevel>[];
    final bids = book?.bids ?? const <OrderBookLevel>[];

    return OkxPanel(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.depthBook,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          if (book == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(S.noBidAsk, style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ),
            )
          else ...[
            for (var i = asks.length - 1; i >= 0; i--)
              _DepthRow(
                label: _askLabel(asks.length - i),
                price: asks[i].price,
                size: asks[i].size,
                color: AppColors.red,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: AppColors.border),
            ),
            for (var i = 0; i < bids.length; i++)
              _DepthRow(
                label: _bidLabel(i + 1),
                price: bids[i].price,
                size: bids[i].size,
                color: AppColors.green,
              ),
          ],
        ],
      ),
    );
  }

  String _askLabel(int level) => '卖$level';

  String _bidLabel(int level) => '买$level';
}

class _DepthRow extends StatelessWidget {
  const _DepthRow({
    required this.label,
    required this.price,
    required this.size,
    required this.color,
  });

  final String label;
  final double price;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              price > 0 ? _priceFmt.format(price) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              size > 0 ? _qtyFmt.format(size) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, color: AppColors.muted2),
            ),
          ),
        ],
      ),
    );
  }
}
