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
            if (widget.showHeader)
              _showOptions ? const _OptionPositionsHeader() : const _PositionsHeader(),
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

class _OptionPositionsHeader extends StatelessWidget {
  const _OptionPositionsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(S.colContract, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ),
          SizedBox(
            width: _pnlColumnWidth,
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

const _pnlColumnWidth = 92.0;

class _PnlColumn extends StatelessWidget {
  const _PnlColumn({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final p = position;
    final pnlColor_ = pnlColor(p.pnl);
    return SizedBox(
      width: _pnlColumnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _money.format(p.pnl),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: pnlColor_,
            ),
          ),
          Text(
            '${_pct.format(p.pnlPct)}%',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(fontSize: 11, color: pnlColor_),
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
    if (isOptionSymbol(position.symbol)) {
      return _OptionPositionRow(position: position, onTapSymbol: onTapSymbol);
    }
    return _StockPositionRow(position: position, onTapSymbol: onTapSymbol);
  }
}

class _OptionPositionRow extends ConsumerWidget {
  const _OptionPositionRow({required this.position, this.onTapSymbol});

  final Position position;
  final VoidCallback? onTapSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = position;
    final isLong = p.side.toLowerCase() != 'short';
    final sideColor = isLong ? AppColors.green : AppColors.red;
    final worthless = isWorthlessOption(p);

    return GlassPanel(
      borderRadius: OkxRadius.md,
      blur: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTapSymbol,
                  child: Text(
                    formatOptionPositionLabel(p.symbol),
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
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.25),
                            children: [
                              TextSpan(text: '${S.colEntry} '),
                              TextSpan(
                                text: _money.format(p.avgCost),
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(text: '  ·  ${_qtyFmt.format(p.qty)}  ·  '),
                              TextSpan(text: '${S.colMark} '),
                              TextSpan(
                                text: _money.format(p.price),
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _PnlColumn(position: p),
            ],
          ),
          if (worthless) ...[
            const SizedBox(height: 6),
            Text(
              S.noLiquidityHint,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          _PositionActionRow(position: p, worthless: worthless),
        ],
      ),
    );
  }
}

class _StockPositionRow extends ConsumerWidget {
  const _StockPositionRow({required this.position, this.onTapSymbol});

  final Position position;
  final VoidCallback? onTapSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = position;
    final isLong = p.side.toLowerCase() != 'short';
    final sideColor = isLong ? AppColors.green : AppColors.red;
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
                          p.symbol,
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
                child: _PnlColumn(position: p),
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
          _PositionActionRow(position: p, worthless: worthless),
        ],
      ),
    );
  }
}

class _PositionActionRow extends ConsumerWidget {
  const _PositionActionRow({required this.position, required this.worthless});

  final Position position;
  final bool worthless;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = position;
    return Row(
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
