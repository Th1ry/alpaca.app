import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/strings.dart';
import '../core/symbol_utils.dart';
import '../features/trade/order_qty_utils.dart';
import '../models/models.dart';
import 'ws_service.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

String orderResultMessage(OrderModel order) {
  final sym = order.symbol.toUpperCase();
  final isOption = isOptionSymbol(sym);
  final qtyStr = formatQtyWithUnitForSymbol(order.effectiveQty, sym);
  final side = S.orderSide(order.side);
  final status = S.orderStatus(order.status);
  final price = order.filledAvgPrice;
  if (price != null && price > 0 && order.isFilled) {
    return '$side $sym $qtyStr · ${_money.format(price)} · $status';
  }
  return '$side $sym $qtyStr · $status';
}

void onOrderCompleted(WidgetRef ref, OrderModel order) {
  final ws = ref.read(wsServiceProvider);
  ws.applyOptimisticOrder(order);
  ws.pollPortfolioNow();
}

void showOrderResultSnackBar(BuildContext context, OrderModel order) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(orderResultMessage(order)),
      duration: const Duration(seconds: 3),
    ),
  );
}
