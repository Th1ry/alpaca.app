import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/symbol_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/portfolio_providers.dart';
import '../../services/alpaca_client.dart';
import '../../services/api_service.dart';

final _qtyFmt = NumberFormat('#,##0.##');

bool _isNoLiquidityError(Object e) {
  if (e is AlpacaApiException && e.statusCode == 409) return true;
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (status == 409) return true;
    if (data == 'no_liquidity') return true;
    if (data is Map && data['detail'] == 'no_liquidity') return true;
    final msg = e.message ?? '';
    if (msg.contains('no_liquidity')) return true;
  }
  return e.toString().contains('no_liquidity');
}

Future<void> confirmDismissPosition(BuildContext context, WidgetRef ref, Position position) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.dismissPosition),
      content: Text(S.dismissPositionConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(S.dismissPosition),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(apiServiceProvider).dismissPosition(position.symbol);
    refreshPortfolio(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.positionDismissed)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> _offerDismissAfterLiquidityFail(
  BuildContext context,
  WidgetRef ref,
  Position position,
) async {
  if (!context.mounted) return;
  final dismiss = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.noLiquidity),
      content: Text('${S.noLiquidityHint}\n${formatOptionPositionLabel(position.symbol)}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(S.dismissPosition),
        ),
      ],
    ),
  );
  if (dismiss == true && context.mounted) {
    await confirmDismissPosition(context, ref, position);
  }
}

Future<void> confirmQuickClose(BuildContext context, WidgetRef ref, Position position) async {
  final worthless = isWorthlessOption(position);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(worthless ? S.tryCloseAnyway : S.quickClose),
      content: Text(
        worthless
            ? '${S.noLiquidityHint}\n${formatOptionPositionLabel(position.symbol)}'
            : '${S.quickCloseConfirm}\n${position.symbol}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
        if (worthless)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              if (context.mounted) {
                confirmDismissPosition(context, ref, position);
              }
            },
            child: Text(S.dismissPosition),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
          child: Text(worthless ? S.tryCloseAnyway : S.confirmClose),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(apiServiceProvider).closePosition(position.symbol, 100);
    refreshPortfolio(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.closeSubmitted)));
    }
  } catch (e) {
    if (_isNoLiquidityError(e)) {
      await _offerDismissAfterLiquidityFail(context, ref, position);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> showPartialCloseSheet(BuildContext context, WidgetRef ref, Position position) async {
  var percent = 50.0;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final closeQty = position.qty * percent / 100;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(S.partialClose, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(position.symbol, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 16),
                Text(
                  '${S.closeRatio}: ${percent.round()}%  ·  ${_qtyFmt.format(closeQty)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: percent,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setState(() => percent = v),
                ),
                Wrap(
                  spacing: 8,
                  children: [25, 50, 75, 100].map((p) {
                    final active = percent.round() == p;
                    return ChoiceChip(
                      label: Text('$p%'),
                      selected: active,
                      onSelected: (_) => setState(() => percent = p.toDouble()),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: Text(S.confirmPartialClose),
                        content: Text(
                          '${position.symbol}\n${S.closeRatio} ${percent.round()}%  (${_qtyFmt.format(closeQty)})',
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, false), child: Text(S.cancel)),
                          FilledButton(
                            onPressed: () => Navigator.pop(dctx, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.red, foregroundColor: Colors.white),
                            child: Text(S.confirmClose),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    try {
                      await ref.read(apiServiceProvider).closePosition(position.symbol, percent);
                      refreshPortfolio(ref);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(S.closeSubmitted)));
                      }
                    } catch (e) {
                      if (_isNoLiquidityError(e)) {
                        await _offerDismissAfterLiquidityFail(context, ref, position);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(S.confirmPartialClose),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showTpSlSheet(BuildContext context, WidgetRef ref, Position position) async {
  final isLong = position.side.toLowerCase() != 'short';
  final tpCtrl = TextEditingController(
    text: (isLong ? position.price * 1.05 : position.price * 0.95).toStringAsFixed(2),
  );
  final slCtrl = TextEditingController(
    text: (isLong ? position.price * 0.95 : position.price * 1.05).toStringAsFixed(2),
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.tpSl, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(position.symbol, style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: tpCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: S.takeProfitPrice),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: slCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: S.stopLossPrice),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final tp = double.tryParse(tpCtrl.text.trim());
                final sl = double.tryParse(slCtrl.text.trim());
                Navigator.pop(ctx);
                try {
                  await ref.read(apiServiceProvider).setPositionBracket(
                        symbol: position.symbol,
                        takeProfitPrice: tp,
                        stopLossPrice: sl,
                      );
                  refreshPortfolio(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(S.tpSlSubmitted)));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text(S.saveTpSl),
            ),
          ],
        ),
      );
    },
  );
  tpCtrl.dispose();
  slCtrl.dispose();
}
