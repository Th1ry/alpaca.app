import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class FloatingCapsuleNavItem {
  const FloatingCapsuleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating glass capsule bottom navigation with sliding highlight.
class FloatingCapsuleNav extends StatelessWidget {
  const FloatingCapsuleNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<FloatingCapsuleNavItem> items;

  static const _duration = Duration(milliseconds: 320);

  /// Bottom inset so scrollable content clears the floating capsule.
  static double overlayInset(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return 56 + 12 + bottom + 12;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.glassTop, AppColors.glassMid, AppColors.glassBottom],
            ),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = items.length;
                final slotW = constraints.maxWidth / count;
                final innerPad = 5.0;
                final pillW = slotW - innerPad * 2;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: _duration,
                      curve: Curves.easeOutCubic,
                      left: slotW * index + innerPad,
                      top: innerPad,
                      bottom: innerPad,
                      width: pillW,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: AppColors.glassPill,
                          border: Border.all(color: AppColors.glassPillBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.glassSpecular,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: _NavSlot(
                              item: items[i],
                              selected: i == index,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingCapsuleNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.glassPill.withValues(alpha: 0.5),
        highlightColor: AppColors.glassPill.withValues(alpha: 0.25),
        child: AnimatedSize(
          duration: FloatingCapsuleNav._duration,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: FloatingCapsuleNav._duration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    key: ValueKey('${item.label}-$selected'),
                    size: selected ? 22 : 20,
                    color: selected ? AppColors.text : AppColors.muted2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: FloatingCapsuleNav._duration,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: selected ? 10 : 9,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.text : AppColors.muted2,
                    height: 1.1,
                  ),
                  child: Text(item.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
