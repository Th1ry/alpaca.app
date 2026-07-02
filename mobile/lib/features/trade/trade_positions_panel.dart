import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/portfolio_providers.dart';
import '../../shared/widgets/positions_list.dart';
import '../../shared/widgets/floating_capsule_nav.dart';
import 'order_history_screen.dart';

/// Fixed bottom panel on trade tab: all positions + link to order history.
/// When [embedded] is true, renders inline inside a parent [SingleChildScrollView].
class TradePositionsPanel extends ConsumerWidget {
  TradePositionsPanel({super.key, this.onTapPosition, this.embedded = false});

  final void Function(Position position)? onTapPosition;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(positionsProvider).valueOrNull?.length ?? 0;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(embedded ? 0 : 16, 10, embedded ? 0 : 8, 0),
      child: Row(
        children: [
          Text(
            '${S.positions}${count > 0 ? ' ($count)' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              refreshPortfolio(ref);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: Text(S.orderHistory),
          ),
        ],
      ),
    );

    final list = PositionsList(showHeader: true, onTapPosition: onTapPosition);

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: AppColors.border),
          header,
          const SizedBox(height: 4),
          list,
        ],
      );
    }

    return Material(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: AppColors.border),
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: FloatingCapsuleNav.overlayInset(context)),
              child: list,
            ),
          ),
        ],
      ),
    );
  }
}
