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
    this.orderBook,
  });

  final String symbol;
  final Quote quote;
  final String Function(double) money;
  final String Function(double) pct;
  final OrderBook? orderBook;

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
                  S.lastPrice,
                  style: TextStyle(fontSize: 10, color: AppColors.muted2, fontWeight: FontWeight.w500),
                ),
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
            child: BidAskStrip(orderBook: orderBook, quote: quote),
          ),
        ],
      ),
    );
  }
}

/// Compact bid / ask beside the symbol header — always from order book L1.
class BidAskStrip extends StatelessWidget {
  const BidAskStrip({super.key, this.quote, this.orderBook});

  final Quote? quote;
  final OrderBook? orderBook;

  OrderBookLevel? _level1(List<OrderBookLevel> levels) {
    if (levels.isEmpty) return null;
    final l = levels.first;
    return l.isReal && l.price > 0 ? l : null;
  }

  @override
  Widget build(BuildContext context) {
    final bid = _level1(orderBook?.bids ?? const <OrderBookLevel>[]);
    final ask = _level1(orderBook?.asks ?? const <OrderBookLevel>[]);
    final q = quote;

    // Fallback to quote BBO only before the first book snapshot arrives.
    final bidPrice = bid?.price ?? (q != null && q.bid > 0 ? q.bid : null);
    final bidSize = bid?.size ?? (q != null && q.bid > 0 ? q.bidSize : null);
    final askPrice = ask?.price ?? (q != null && q.ask > 0 ? q.ask : null);
    final askSize = ask?.size ?? (q != null && q.ask > 0 ? q.askSize : null);

    if (bidPrice == null && askPrice == null) {
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
            price: bidPrice,
            size: bidSize,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _DepthColumn(
            label: S.ask1,
            price: askPrice,
            size: askSize,
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
