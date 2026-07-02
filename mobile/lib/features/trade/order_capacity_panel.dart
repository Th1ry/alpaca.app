import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'order_qty_utils.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _qtyFmt = NumberFormat('#,##0.##');

class OrderCapacityPanel extends StatelessWidget {
  const OrderCapacityPanel({
    super.key,
    required this.side,
    required this.account,
    required this.orderPrice,
    required this.activeSymbol,
    required this.underlying,
    this.selectedOcc,
    this.positions = const [],
  });

  final String side;
  final AccountSummary? account;
  final double orderPrice;
  final String activeSymbol;
  final String underlying;
  final String? selectedOcc;
  final List<Position> positions;

  @override
  Widget build(BuildContext context) {
    final acct = account;
    final isBuy = side.toLowerCase() == 'buy';
    final maxLabel = isBuy ? S.maxBuyQty : S.maxSellQty;
    final maxQty = isBuy
        ? computeMaxBuyQty(account: acct, orderPrice: orderPrice, activeSymbol: activeSymbol)
        : computeMaxSellQty(positions: positions, underlying: underlying, selectedOcc: selectedOcc);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(OkxRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          _CapacityRow(
            label: S.buyingPower,
            value: acct != null ? _money.format(acct.buyingPower) : '—',
          ),
          const SizedBox(height: 6),
          _CapacityRow(
            label: S.marginBuyingPower,
            value: acct != null ? _money.format(acct.marginBuyingPower) : '—',
          ),
          const SizedBox(height: 6),
          _CapacityRow(
            label: maxLabel,
            value: maxQty != null ? _qtyFmt.format(maxQty) : '—',
            valueColor: isBuy ? AppColors.green : AppColors.red,
          ),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
