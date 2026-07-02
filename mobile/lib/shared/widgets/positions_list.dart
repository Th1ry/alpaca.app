import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/platform_ui.dart';
import '../../core/strings.dart';
import '../../core/symbol_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../features/trade/position_actions.dart';
import '../../models/models.dart';
import '../../providers/portfolio_providers.dart';
import 'widgets.dart';
import 'okx_ui.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _pct = NumberFormat('+#0.00;-#0.00');
final _qtyFmt = NumberFormat('#,##0.##');

class CryptoPositionsTable extends ConsumerStatefulWidget {
  const CryptoPositionsTable({super.key, this.onTapPosition, this.showHeader = true});

  final void Function(Position position)? onTapPosition;
  final bool showHeader;

  @override
  ConsumerState<CryptoPositionsTable> createState() => _CryptoPositionsTableState();
}

class _CryptoPositionsTableState extends ConsumerState<CryptoPositionsTable> {
  bool _showOptions = false;
  bool _didPickInitialTab = false;

  void _maybePickInitialTab(List<Position> stocks, List<Position> options) {
    if (_didPickInitialTab) return;
    _didPickInitialTab = true;
    if (stocks.isEmpty && options.isNotEmpty) {
      _showOptions = true;
    }
  }

  Widget _buildToggle(int stockCount, int optionCount) {
    return OkxDualToggle(
      leftLabel: '${S.stockPositions} ($stockCount)',
      rightLabel: '${S.optionPositions} ($optionCount)',
      showRight: _showOptions,
      onChanged: (v) => setState(() => _showOptions = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(positionsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(S.loadFailed, style: TextStyle(color: AppColors.muted)),
      ),
      data: (positions) {
        final stocks = positions.where((p) => !isOptionSymbol(p.symbol)).toList();
        final options = positions.where((p) => isOptionSymbol(p.symbol)).toList();
        _maybePickInitialTab(stocks, options);

        final list = _showOptions ? options : stocks;
        final emptyText = _showOptions ? S.noOptionPositions : S.noStockPositions;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToggle(stocks.length, options.length),
            if (widget.showHeader) const _PositionsHeader(),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(emptyText, style: TextStyle(color: AppColors.muted))),
              )
            else
              ...list.map((p) => Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: _CryptoPositionRow(
                      position: p,
                      onTapSymbol: widget.onTapPosition == null
                          ? null
                          : () => widget.onTapPosition!(p),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class PositionsList extends CryptoPositionsTable {
  const PositionsList({super.key, super.onTapPosition, super.showHeader});
}

class _PositionsHeader extends StatelessWidget {
  const _PositionsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(S.colContract, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(S.colSize, style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              S.colUpnl,
              textAlign: TextAlign.end,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _CryptoPositionRow extends ConsumerWidget {
  const _CryptoPositionRow({required this.position, this.onTapSymbol});

  final Position position;
  final VoidCallback? onTapSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = position;
    final isLong = p.side.toLowerCase() != 'short';
    final sideColor = isLong ? AppColors.green : AppColors.red;
    final pnlColor_ = pnlColor(p.pnl);
    final worthless = isWorthlessOption(p);

    return GlassPanel(
      borderRadius: OkxRadius.md,
      blur: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onTapSymbol,
                        child: Text(
                          isOptionSymbol(p.symbol)
                              ? formatOptionPositionLabel(p.symbol)
                              : p.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: onTapSymbol != null ? AppColors.accentSoft : AppColors.text,
                            decoration: onTapSymbol != null ? TextDecoration.underline : null,
                            decorationColor: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SideBadge(label: S.positionSide(p.side), color: sideColor),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _qtyFmt.format(p.qty),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money.format(p.pnl),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pnlColor_,
                      ),
                    ),
                    Text(
                      '${_pct.format(p.pnlPct)}%',
                      style: TextStyle(fontSize: 11, color: pnlColor_),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (worthless)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                S.noLiquidityHint,
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          Row(
            children: [
              _MetaChip(label: S.colEntry, value: _money.format(p.avgCost)),
              const SizedBox(width: 12),
              _MetaChip(label: S.colMark, value: _money.format(p.price)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: worthless
                      ? () => confirmDismissPosition(context, ref, p)
                      : () => confirmQuickClose(context, ref, p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: worthless ? AppColors.muted : AppColors.red,
                    side: BorderSide(
                      color: worthless
                          ? AppColors.muted.withValues(alpha: 0.5)
                          : AppColors.red.withValues(alpha: 0.6),
                    ),
                    backgroundColor: worthless ? Colors.white.withValues(alpha: 0.04) : AppColors.redDim,
                    padding: EdgeInsets.symmetric(
                      vertical: PlatformUi.isMobile ? 10 : 6,
                    ),
                  ),
                  child: Text(
                    worthless ? S.dismissPosition : S.quickClose,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              if (!worthless) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showPartialCloseSheet(context, ref, p),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      padding: EdgeInsets.symmetric(
                      vertical: PlatformUi.isMobile ? 10 : 6,
                    ),
                    ),
                    child: Text(S.partialClose, style: const TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showTpSlSheet(context, ref, p),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      padding: EdgeInsets.symmetric(
                      vertical: PlatformUi.isMobile ? 10 : 6,
                    ),
                    ),
                    child: Text(S.tpSl, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => confirmQuickClose(context, ref, p),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      padding: EdgeInsets.symmetric(
                      vertical: PlatformUi.isMobile ? 10 : 6,
                    ),
                    ),
                    child: Text(S.tryCloseAnyway, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 11, color: AppColors.muted),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
