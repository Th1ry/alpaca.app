import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/platform_ui.dart';
import '../../core/theme/app_theme.dart';

Color pnlColor(double v) => v >= 0 ? AppColors.upColor : AppColors.downColor;

/// Soft color blobs so glass blur has content to refract.
class GlassAmbientLayer extends StatelessWidget {
  const GlassAmbientLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final blobs = AppColors.glassBlobs;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(blobs[0], 200)),
          Positioned(top: 180, left: -70, child: _blob(blobs[1 % blobs.length], 170)),
          Positioned(bottom: 120, right: -30, child: _blob(blobs[2 % blobs.length], 150)),
          Positioned(bottom: -40, left: 40, child: _blob(blobs[3 % blobs.length], 120)),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Liquid glass / glassmorphism container.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = OkxRadius.lg,
    this.blur = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.glassSpecular,
            blurRadius: 1,
            offset: const Offset(0, -0.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.glassTop, AppColors.glassMid, AppColors.glassBottom],
                stops: const [0.0, 0.45, 1.0],
              ),
              border: Border.all(color: AppColors.glassBorder, width: 0.8),
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: panel,
      ),
    );
  }
}

/// Groups list rows inside one glass panel.
class GlassListGroup extends StatelessWidget {
  const GlassListGroup({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return GlassPanel(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0.5, color: AppColors.glassDivider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Two-option sliding capsule — shared by stock/option, chart/chain, market/limit, etc.
class OkxCapsuleSwitch extends StatelessWidget {
  const OkxCapsuleSwitch({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.showRight,
    required this.onChanged,
    this.height = 40,
    this.pillColor,
    this.leftPillColor,
    this.rightPillColor,
    this.rightEnabled = true,
    this.leftEnabled = true,
    this.margin,
    this.padding = const EdgeInsets.all(4),
  });

  final String leftLabel;
  final String rightLabel;
  final bool showRight;
  final ValueChanged<bool> onChanged;
  final double height;
  final Color? pillColor;
  final Color? leftPillColor;
  final Color? rightPillColor;
  final bool rightEnabled;
  final bool leftEnabled;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;

  static const duration = Duration(milliseconds: 280);

  static Color _selectedLabelColor(Color pill) {
    if (pill == AppColors.green || pill == AppColors.red || pill == AppColors.accent) {
      return Colors.white;
    }
    return AppColors.text;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = pillColor ?? AppColors.glassPill;
    final activePill = showRight
        ? (rightPillColor ?? leftPillColor ?? fallback)
        : (leftPillColor ?? rightPillColor ?? fallback);

    Widget track = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.elevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(OkxRadius.pill),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45), width: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotW = constraints.maxWidth / 2;
          final glow = activePill.withValues(alpha: 0.28);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: showRight ? slotW : 0,
                top: 0,
                bottom: 0,
                width: slotW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: activePill,
                    borderRadius: BorderRadius.circular(OkxRadius.pill - 4),
                    border: Border.all(
                      color: AppColors.glassPillBorder.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glow,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _CapsuleSlot(
                      label: leftLabel,
                      selected: !showRight,
                      enabled: leftEnabled,
                      selectedColor: leftPillColor != null && !showRight
                          ? _selectedLabelColor(leftPillColor!)
                          : null,
                      onTap: () => onChanged(false),
                    ),
                  ),
                  Expanded(
                    child: _CapsuleSlot(
                      label: rightLabel,
                      selected: showRight,
                      enabled: rightEnabled,
                      selectedColor: rightPillColor != null && showRight
                          ? _selectedLabelColor(rightPillColor!)
                          : null,
                      onTap: () => onChanged(true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (margin != null) {
      track = Padding(padding: margin!, child: track);
    }
    return track;
  }
}

class _CapsuleSlot extends StatelessWidget {
  const _CapsuleSlot({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(OkxRadius.pill),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: OkxCapsuleSwitch.duration,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: !enabled
                  ? AppColors.muted.withValues(alpha: 0.45)
                  : selected
                      ? (selectedColor ?? AppColors.text)
                      : AppColors.muted,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

/// Buy / sell toggle — single track with sliding colored capsule.
class OkxBuySellBar extends StatelessWidget {
  const OkxBuySellBar({
    super.key,
    required this.side,
    required this.onChanged,
    this.buyLabel = '买入',
    this.sellLabel = '卖出',
  });

  final String side;
  final ValueChanged<String> onChanged;
  final String buyLabel;
  final String sellLabel;

  @override
  Widget build(BuildContext context) {
    final isBuy = side.toLowerCase() == 'buy';
    return OkxCapsuleSwitch(
      leftLabel: buyLabel,
      rightLabel: sellLabel,
      showRight: !isBuy,
      onChanged: (sell) => onChanged(sell ? 'sell' : 'buy'),
      leftPillColor: AppColors.green,
      rightPillColor: AppColors.red,
    );
  }
}

/// Market / Limit toggle — sliding capsule.
class OkxOrderTypeSwitch extends StatelessWidget {
  const OkxOrderTypeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.marketLabel = 'Market',
    this.limitLabel = 'Limit',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String marketLabel;
  final String limitLabel;

  @override
  Widget build(BuildContext context) {
    return OkxCapsuleSwitch(
      leftLabel: marketLabel,
      rightLabel: limitLabel,
      showRight: value == 'limit',
      onChanged: (limit) => onChanged(limit ? 'limit' : 'market'),
      height: 40,
      leftPillColor: AppColors.accent,
      rightPillColor: AppColors.accentSoft,
    );
  }
}

/// Horizontal timeframe / period chips — soft capsules, no underline.
class OkxSegmentRow extends StatelessWidget {
  const OkxSegmentRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.fontSize = 11,
  });

  final List<(String key, String label)> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _SegmentChip(
              label: options[i].$2,
              active: selected == options[i].$1,
              fontSize: fontSize,
              onTap: () => onSelect(options[i].$1),
            ),
            if (i < options.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.active,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool active;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OkxRadius.pill),
        splashColor: AppColors.accentSoft.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: OkxCapsuleSwitch.duration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: PlatformUi.isMobile ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.glassPill : Colors.transparent,
            borderRadius: BorderRadius.circular(OkxRadius.pill),
            border: Border.all(
              color: active
                  ? AppColors.glassPillBorder.withValues(alpha: 0.7)
                  : AppColors.border.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AppColors.text : AppColors.muted2,
            ),
          ),
        ),
      ),
    );
  }
}

class OkxSectionHeader extends StatelessWidget {
  const OkxSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Large symbol + price header (OKX trade top).
class OkxQuoteHeader extends StatelessWidget {
  const OkxQuoteHeader({
    super.key,
    required this.symbol,
    required this.price,
    required this.changePct,
    required this.change,
    required this.money,
    required this.pct,
  });

  final String symbol;
  final double price;
  final double changePct;
  final double change;
  final String Function(double) money;
  final String Function(double) pct;

  @override
  Widget build(BuildContext context) {
    final up = change >= 0;
    final color = pnlColor(change);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol, style: TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  money(price),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: up ? AppColors.green : AppColors.red,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${pct(changePct)}%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                money(change),
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asset hero card — OKX wallet overview.
class OkxAssetHero extends StatelessWidget {
  const OkxAssetHero({
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
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1),
          ),
          if (sub != null) ...[
            const SizedBox(height: 8),
            onSubTap != null
                ? InkWell(
                    onTap: onSubTap,
                    borderRadius: BorderRadius.circular(OkxRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(sub!, style: TextStyle(color: subColor ?? AppColors.muted, fontSize: 13)),
                          Icon(Icons.chevron_right, size: 16, color: subColor ?? AppColors.muted),
                        ],
                      ),
                    ),
                  )
                : Text(sub!, style: TextStyle(color: subColor ?? AppColors.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class OkxMiniStat extends StatelessWidget {
  const OkxMiniStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        borderRadius: OkxRadius.md,
        blur: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class OkxPanel extends StatelessWidget {
  const OkxPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding ?? const EdgeInsets.all(12),
      borderRadius: OkxRadius.lg,
      child: child,
    );
  }
}

class OkxDivider extends StatelessWidget {
  const OkxDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 0.5, color: AppColors.border);
}

/// OKX markets list row — flat, no card shadow.
class OkxMarketRow extends StatelessWidget {
  const OkxMarketRow({
    super.key,
    required this.symbol,
    required this.subtitle,
    required this.price,
    required this.changePct,
    required this.onTap,
    this.trailing,
  });

  final String symbol;
  final String subtitle;
  final String price;
  final double changePct;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = pnlColor(changePct);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(symbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Position type toggle — sliding capsule in glass panel.
class OkxDualToggle extends StatelessWidget {
  const OkxDualToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.showRight,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool showRight;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(6),
      borderRadius: OkxRadius.pill,
      blur: 14,
      child: OkxCapsuleSwitch(
        leftLabel: leftLabel,
        rightLabel: rightLabel,
        showRight: showRight,
        onChanged: onChanged,
        height: 38,
        padding: const EdgeInsets.all(3),
        leftPillColor: AppColors.green.withValues(alpha: 0.88),
        rightPillColor: AppColors.accentSoft,
      ),
    );
  }
}
