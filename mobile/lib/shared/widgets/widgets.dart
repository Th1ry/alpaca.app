import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/platform_ui.dart';
import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'okx_ui.dart';

export 'okx_ui.dart' show pnlColor;

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _pct = NumberFormat('+#0.00;-#0.00');

class ApiErrorView extends StatelessWidget {
  const ApiErrorView({super.key, required this.onRetry, this.detail});

  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(S.loadFailed, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              detail ?? S.loadFailedHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(S.retry)),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    this.onSubTap,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final VoidCallback? onSubTap;

  @override
  Widget build(BuildContext context) {
    return OkxAssetHero(
      label: label,
      value: value,
      sub: sub,
      subColor: subColor,
      onSubTap: onSubTap,
    );
  }
}

class PnlCurveChart extends StatelessWidget {
  const PnlCurveChart({
    super.key,
    required this.points,
    required this.totalPnl,
    this.height = 120,
  });

  final List<PnlPoint> points;
  final double totalPnl;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return GlassPanel(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(S.noAnalyticsData, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ),
      );
    }
    final up = totalPnl >= 0;
    final color = up ? AppColors.upColor : AppColors.downColor;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].cumulativePnl),
    ];
    final ys = spots.map((s) => s.y).toList();
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final pad = ((maxY - minY).abs() * 0.1).clamp(1.0, double.infinity);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsStatCard extends StatelessWidget {
  const AnalyticsStatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return OkxPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class WatchlistTile extends StatelessWidget {
  const WatchlistTile({
    super.key,
    required this.quote,
    required this.sparkline,
    required this.onTap,
  });

  final Quote quote;
  final List<Bar> sparkline;
  final VoidCallback onTap;

  static final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final spark = _buildSparkChart(sparkline, quote.change);

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      borderRadius: OkxRadius.md,
      blur: 14,
      onTap: onTap,
      child: OkxMarketRow(
        symbol: quote.symbol,
        subtitle: quote.name,
        price: _money.format(quote.price),
        changePct: quote.changePct,
        onTap: onTap,
        trailing: spark,
      ),
    );
  }

  Widget? _buildSparkChart(List<Bar> bars, double change) {
    if (bars.isEmpty) return null;
    var points = bars.length > 48 ? bars.sublist(bars.length - 48) : bars;
    if (points.length == 1) {
      final b = points.first;
      points = [
        b,
        Bar(time: b.time + 60, open: b.close, high: b.close, low: b.close, close: b.close),
      ];
    }
    final closes = points.map((b) => b.close).toList();
    var minC = closes.reduce((a, b) => a < b ? a : b);
    var maxC = closes.reduce((a, b) => a > b ? a : b);
    if (minC == maxC) {
      minC -= minC.abs() * 0.002 + 0.01;
      maxC += maxC.abs() * 0.002 + 0.01;
    }
    final pad = (maxC - minC) * 0.06;

    return IgnorePointer(
      child: SizedBox(
        width: 56,
        height: 28,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: minC - pad,
            maxY: maxC + pad,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            clipData: const FlClipData.all(),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].close),
                ],
                isCurved: false,
                color: pnlColor(change),
                barWidth: 1.0,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CandleChart extends StatefulWidget {
  const CandleChart({super.key, required this.bars, this.timeframe = '5m'});

  final List<Bar> bars;
  final String timeframe;

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> {
  static const _minScale = 0.6;
  static const _maxScale = 12.0;

  double _scale = 1.0;
  double _startIndex = 0;
  double _gestureStartScale = 1.0;

  bool _crosshair = false;
  Offset? _crosshairPos;
  int _pointersDown = 0;
  int? _activePointer;
  Offset? _pointerDownPos;
  double? _panAnchorIndex;
  Timer? _longPressTimer;
  DateTime? _pointerDownAt;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CandleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeframe != widget.timeframe || oldWidget.bars != widget.bars) {
      _scale = 1.0;
      _startIndex = 0;
      _crosshair = false;
      _crosshairPos = null;
    }
  }

  double _slotWidth(double chartW) {
    if (widget.bars.isEmpty) return 8;
    return (chartW / widget.bars.length) * _scale;
  }

  double _clampedStartIndex(double chartW) {
    if (widget.bars.isEmpty) return 0;
    final slotW = _slotWidth(chartW);
    if (slotW <= 0) return 0;
    final visible = chartW / slotW;
    final maxStart = math.max(0.0, widget.bars.length - visible);
    return _startIndex.clamp(0.0, maxStart);
  }

  void _clampStartIndex(double chartW) {
    final clamped = _clampedStartIndex(chartW);
    if (clamped != _startIndex) _startIndex = clamped;
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _dismissCrosshair() {
    if (!_crosshair) return;
    setState(() {
      _crosshair = false;
      _crosshairPos = null;
    });
  }

  void _handlePointerDown(PointerDownEvent event, double chartW) {
    _pointersDown++;
    if (_pointersDown > 1) {
      _cancelLongPress();
      return;
    }

    _activePointer = event.pointer;
    _pointerDownPos = event.localPosition;
    _panAnchorIndex = _startIndex;
    _pointerDownAt = DateTime.now();

    if (_crosshair) {
      setState(() => _crosshairPos = event.localPosition);
      return;
    }

    _cancelLongPress();
    _longPressTimer = Timer(PlatformUi.chartLongPressHold, () {
      if (!mounted || _activePointer != event.pointer || _pointersDown != 1) return;
      setState(() {
        _crosshair = true;
        _crosshairPos = _pointerDownPos;
      });
    });
  }

  void _handlePointerMove(PointerMoveEvent event, double chartW) {
    if (event.pointer != _activePointer) return;

    if (_crosshair) {
      setState(() => _crosshairPos = event.localPosition);
      return;
    }

    final origin = _pointerDownPos;
    if (origin == null || _panAnchorIndex == null) return;
    final delta = event.localPosition - origin;
    if (delta.distance > PlatformUi.chartPanTouchSlop) {
      _cancelLongPress();
      final slotW = _slotWidth(chartW);
      if (slotW > 0) {
        setState(() {
          _startIndex = _panAnchorIndex! - delta.dx / slotW;
          _clampStartIndex(chartW);
        });
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event, double chartW) {
    _finishPointer(event.pointer, event.localPosition, chartW);
  }

  void _handlePointerCancel(PointerCancelEvent event, double chartW) {
    _finishPointer(event.pointer, event.localPosition, chartW);
  }

  void _finishPointer(int pointer, Offset localPosition, double chartW) {
    if (pointer == _activePointer) {
      final downAt = _pointerDownAt;
      final origin = _pointerDownPos;
      final moved = origin == null ? 0.0 : (localPosition - origin).distance;
      final held = downAt == null ? Duration.zero : DateTime.now().difference(downAt);

      if (_crosshair &&
          moved < PlatformUi.chartTapSlop &&
          held < PlatformUi.chartLongPressHold + const Duration(milliseconds: 120)) {
        _dismissCrosshair();
      }

      _activePointer = null;
      _pointerDownPos = null;
      _panAnchorIndex = null;
      _pointerDownAt = null;
      _cancelLongPress();
    }

    _pointersDown = math.max(0, _pointersDown - 1);
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final chartW = box.size.width - _CandlePainter.padL - _CandlePainter.padR;
    setState(() {
      final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      _scale = (_scale * factor).clamp(_minScale, _maxScale);
      _clampStartIndex(chartW);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bars.isEmpty) {
      return Center(child: Text(S.noChartData, style: TextStyle(color: AppColors.muted)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartW = constraints.maxWidth - _CandlePainter.padL - _CandlePainter.padR;
        final visibleStart = _clampedStartIndex(chartW);

        return Listener(
          onPointerDown: (e) => _handlePointerDown(e, chartW),
          onPointerMove: (e) => _handlePointerMove(e, chartW),
          onPointerUp: (e) => _handlePointerUp(e, chartW),
          onPointerCancel: (e) => _handlePointerCancel(e, chartW),
          onPointerSignal: PlatformUi.chartScrollZoomEnabled ? _handleScroll : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) {
              _cancelLongPress();
              _gestureStartScale = _scale;
            },
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) {
                setState(() {
                  _scale = (_gestureStartScale * details.scale).clamp(_minScale, _maxScale);
                  _clampStartIndex(chartW);
                });
              }
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CandlePainter(
                bars: widget.bars,
                timeframe: widget.timeframe,
                scale: _scale,
                startIndex: visibleStart,
                crosshairActive: _crosshair,
                crosshairPosition: _crosshairPos,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.bars,
    required this.timeframe,
    required this.scale,
    required this.startIndex,
    this.crosshairActive = false,
    this.crosshairPosition,
  });

  final List<Bar> bars;
  final String timeframe;
  final double scale;
  final double startIndex;
  final bool crosshairActive;
  final Offset? crosshairPosition;

  static const padL = 8.0;
  static const padR = 48.0;
  static const padT = 6.0;
  static const padB = 22.0;
  static final _labelStyle = TextStyle(color: AppColors.muted, fontSize: 10);
  static final _priceLabelStyle = TextStyle(color: AppColors.muted, fontSize: 10);
  static final _crosshairLabelStyle = TextStyle(
    color: AppColors.text,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;
    final slot = (chartW / bars.length) * scale;
    final first = startIndex.floor().clamp(0, bars.length - 1);
    final last = math.min(bars.length, (startIndex + chartW / slot).ceil() + 1);

    var minY = bars[first].low;
    var maxY = bars[first].high;
    for (var i = first; i < last; i++) {
      minY = math.min(minY, bars[i].low);
      maxY = math.max(maxY, bars[i].high);
    }
    var range = maxY - minY;
    if (range <= 0) {
      minY -= 1;
      maxY += 1;
      range = 2;
    } else {
      minY -= range * 0.04;
      maxY += range * 0.04;
      range = maxY - minY;
    }

    double yOf(double price) => padT + chartH * (1 - (price - minY) / range);
    final bodyW = math.max(slot * 0.62, 2.0);

    _drawPriceAxis(canvas, size, minY, maxY, yOf);

    final axisPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(padL, padT + chartH),
      Offset(size.width - padR, padT + chartH),
      axisPaint,
    );

    for (var i = first; i < last; i++) {
      final b = bars[i];
      final cx = padL + (i - startIndex) * slot + slot / 2;
      if (cx < padL - slot || cx > size.width - padR + slot) continue;

      final bull = b.close >= b.open;
      final color = bull ? AppColors.upColor : AppColors.downColor;
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      final bodyPaint = Paint()..color = color;

      canvas.drawLine(Offset(cx, yOf(b.high)), Offset(cx, yOf(b.low)), wickPaint);

      final top = yOf(math.max(b.open, b.close));
      final bottom = yOf(math.min(b.open, b.close));
      final bodyH = math.max(bottom - top, 1.0);
      canvas.drawRect(Rect.fromLTWH(cx - bodyW / 2, top, bodyW, bodyH), bodyPaint);
    }

    _drawTimeLabels(canvas, size, slot, first, last);

    if (crosshairActive && crosshairPosition != null) {
      _drawCrosshair(canvas, size, slot, first, last, minY, maxY, range, yOf);
    }
  }

  void _drawCrosshair(
    Canvas canvas,
    Size size,
    double slot,
    int first,
    int last,
    double minY,
    double maxY,
    double range,
    double Function(double) yOf,
  ) {
    final pos = crosshairPosition!;
    final chartH = size.height - padT - padB;
    final chartW = size.width - padL - padR;

    final rawIndex = (pos.dx - padL) / slot + startIndex;
    final index = rawIndex.round().clamp(0, bars.length - 1);
    final snapX = padL + (index - startIndex) * slot + slot / 2;
    final y = pos.dy.clamp(padT, padT + chartH);
    final price = minY + (1 - (y - padT) / chartH) * range;

    final linePaint = Paint()
      ..color = AppColors.accentSoft.withValues(alpha: 0.9)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(snapX, padT), Offset(snapX, padT + chartH), linePaint);
    canvas.drawLine(Offset(padL, y), Offset(padL + chartW, y), linePaint);

    canvas.drawCircle(
      Offset(snapX, y),
      3.5,
      Paint()..color = AppColors.accent,
    );
    canvas.drawCircle(
      Offset(snapX, y),
      3.5,
      Paint()
        ..color = AppColors.bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _drawCrosshairTag(
      canvas,
      Offset(snapX, padT + chartH + 2),
      _formatAxisTime(_chartTime(bars[index].time)),
      anchorMode: _TagAnchor.topCenter,
    );
    _drawCrosshairTag(
      canvas,
      Offset(size.width - padR + 2, y),
      _formatPrice(price),
      anchorMode: _TagAnchor.centerLeft,
    );
  }

  void _drawCrosshairTag(
    Canvas canvas,
    Offset anchor,
    String text, {
    required _TagAnchor anchorMode,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _crosshairLabelStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const hPad = 5.0;
    const vPad = 2.0;
    final w = tp.width + hPad * 2;
    final h = tp.height + vPad * 2;
    late Offset topLeft;
    switch (anchorMode) {
      case _TagAnchor.topCenter:
        topLeft = Offset(anchor.dx - w / 2, anchor.dy);
      case _TagAnchor.centerLeft:
        topLeft = Offset(anchor.dx, anchor.dy - h / 2);
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = AppColors.elevated.withValues(alpha: 0.95),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
    tp.paint(canvas, Offset(topLeft.dx + hPad, topLeft.dy + vPad));
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(1);
    if (price >= 100) return price.toStringAsFixed(2);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(3);
  }

  void _drawPriceAxis(Canvas canvas, Size size, double minY, double maxY, double Function(double) yOf) {
    const tickCount = 5;
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;

    for (var i = 0; i <= tickCount; i++) {
      final frac = i / tickCount;
      final price = maxY - (maxY - minY) * frac;
      final y = yOf(price);

      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);

      final label = _formatPrice(price);
      final tp = TextPainter(
        text: TextSpan(text: label, style: _priceLabelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 1, y - tp.height / 2));
    }
  }

  DateTime _chartTime(int unixSec) => DateTime.fromMillisecondsSinceEpoch(
        unixSec * 1000,
        isUtc: true,
      ).add(Duration(hours: AppColors.chartTimezoneOffsetHours));

  String _formatAxisTime(DateTime dt) {
    final tf = timeframe.toLowerCase();
    if (tf == '1d') return DateFormat('yyyy/MM/dd').format(dt);
    if (tf.endsWith('h')) return DateFormat('MM/dd HH:mm').format(dt);
    return DateFormat('MM/dd HH:mm').format(dt);
  }

  void _drawTimeLabels(Canvas canvas, Size size, double slot, int first, int last) {
    const minGap = 64.0;
    final step = math.max(1, (minGap / slot).ceil());
    var i = (first ~/ step) * step;
    if (i < first) i += step;

    for (; i < last; i += step) {
      final cx = padL + (i - startIndex) * slot + slot / 2;
      if (cx < padL || cx > size.width - padR) continue;

      final label = _formatAxisTime(_chartTime(bars[i].time));
      final tp = TextPainter(
        text: TextSpan(text: label, style: _labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - padB + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.timeframe != timeframe ||
      oldDelegate.scale != scale ||
      oldDelegate.startIndex != startIndex ||
      oldDelegate.crosshairActive != crosshairActive ||
      oldDelegate.crosshairPosition != crosshairPosition;
}

enum _TagAnchor { topCenter, centerLeft }

class PositionBar extends StatelessWidget {
  const PositionBar({super.key, this.position, this.compact = false});

  final Position? position;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Text(S.noPosition, style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    final p = position!;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(
          children: [
            Expanded(
              child: Text('${S.orderSide(p.side)} ${p.symbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text('${p.qty} @ ${_money.format(p.avgCost)}'),
            const SizedBox(width: 12),
            Text(
              '${_money.format(p.pnl)} (${_pct.format(p.pnlPct)}%)',
              style: TextStyle(color: pnlColor(p.pnl)),
            ),
          ],
        ),
      ),
    );
  }
}
