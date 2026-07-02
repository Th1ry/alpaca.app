import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../shared/widgets/okx_ui.dart';

final _priceFmt = NumberFormat('#,##0.00');
final _qtyFmt = NumberFormat('#,##0');

/// Symbol + last price + bid/ask strip for the trade page top bar.
class TradeQuoteHeader extends StatelessWidget {
  const TradeQuoteHeader({
    super.key,
    required this.symbol,
    required this.quote,
    required this.money,
    required this.pct,
  });

  final String symbol;
  final Quote quote;
  final String Function(double) money;
  final String Function(double) pct;

  @override
  Widget build(BuildContext context) {
    final up = quote.change >= 0;
    final color = pnlColor(quote.change);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol, style: TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  money(quote.price),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: up ? AppColors.green : AppColors.red,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pct(quote.changePct)}%  ${money(quote.change)}',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: BidAskStrip(quote: quote),
          ),
        ],
      ),
    );
  }
}

/// Compact bid / ask beside the symbol header.
class BidAskStrip extends StatelessWidget {
  const BidAskStrip({super.key, this.quote});

  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final hasAsk = q != null && q.ask > 0;
    final hasBid = q != null && q.bid > 0;

    if (q == null || (!hasAsk && !hasBid)) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(S.noBidAsk, style: TextStyle(color: AppColors.muted, fontSize: 10)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _DepthColumn(
            label: S.bid1,
            price: hasBid ? q.bid : null,
            size: hasBid ? q.bidSize : null,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DepthColumn(
            label: S.ask1,
            price: hasAsk ? q.ask : null,
            size: hasAsk ? q.askSize : null,
            color: AppColors.red,
          ),
        ),
      ],
    );
  }
}

class _DepthColumn extends StatelessWidget {
  const _DepthColumn({
    required this.label,
    required this.price,
    required this.size,
    required this.color,
  });

  final String label;
  final double? price;
  final double? size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final priceText = price != null && price! > 0 ? _priceFmt.format(price) : '—';
    final sizeText = size != null && size! > 0 ? _qtyFmt.format(size) : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            priceText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
        Text(
          sizeText,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9, color: AppColors.muted2, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
