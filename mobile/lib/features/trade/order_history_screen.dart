import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../features/trade/order_qty_utils.dart';
import '../../providers/portfolio_providers.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(S.orderHistory)),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => refreshPortfolio(ref),
            child: Text(S.retry),
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Text(S.noOrders, style: TextStyle(color: AppColors.muted)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              refreshPortfolio(ref);
              await ref.read(ordersProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = orders[i];
                return ListTile(
                  title: Text('${S.orderSide(o.side)} ${o.symbol}'),
                  subtitle: Text(
                    '${formatQtyWithUnitForSymbol(o.qty, o.symbol)} · ${S.orderTypeLabel(o.type)} · ${S.orderStatus(o.status)}',
                  ),
                  trailing: o.filledAvgPrice != null
                      ? Text(NumberFormat.currency(symbol: '\$').format(o.filledAvgPrice))
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
