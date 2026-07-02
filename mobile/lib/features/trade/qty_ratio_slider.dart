import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import 'order_qty_utils.dart';

class QtyRatioSlider extends StatefulWidget {
  const QtyRatioSlider({
    super.key,
    required this.symbol,
    required this.maxQty,
    required this.isOption,
    required this.qtyCtrl,
  });

  /// Active order symbol; ratio resets only when this changes.
  final String symbol;
  final double maxQty;
  final bool isOption;
  final TextEditingController qtyCtrl;

  @override
  State<QtyRatioSlider> createState() => _QtyRatioSliderState();
}

class _QtyRatioSliderState extends State<QtyRatioSlider> {
  double _ratio = 0;

  @override
  void didUpdateWidget(covariant QtyRatioSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      setState(() => _ratio = 0);
      return;
    }
    if (oldWidget.maxQty != widget.maxQty) {
      _applyRatio(_ratio);
    }
  }

  void _applyRatio(double ratio) {
    final clamped = ratio.clamp(0.0, 1.0);
    final qty = qtyFromRatio(clamped, widget.maxQty, isOption: widget.isOption);
    widget.qtyCtrl.text = formatOrderQty(qty, isOption: widget.isOption);
    if (_ratio != clamped) setState(() => _ratio = clamped);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.maxQty > 0;
    final pct = (_ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(S.fundsRatio, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const Spacer(),
            Text(
              '$pct%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: _ratio,
            min: 0,
            max: 1,
            divisions: 100,
            label: '$pct%',
            activeColor: AppColors.accent,
            inactiveColor: AppColors.border,
            onChanged: enabled
                ? (v) {
                    setState(() => _ratio = v);
                    _applyRatio(v);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
