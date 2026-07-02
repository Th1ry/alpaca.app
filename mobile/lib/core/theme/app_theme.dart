import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../display_config.dart';

/// Runtime design tokens — updated when theme / preferences change.
class AppColors {
  static Color bg = const Color(0xFF000000);
  static Color surface = const Color(0xFF121212);
  static Color card = const Color(0xFF1A1A1A);
  static Color elevated = const Color(0xFF252525);
  static Color border = const Color(0xFF2B2B2B);
  static Color borderLight = const Color(0x1FFFFFFF);
  static Color text = const Color(0xFFFFFFFF);
  static Color muted = const Color(0xFF8B8B8B);
  static Color muted2 = const Color(0xFF5E5E5E);
  static Color green = const Color(0xFF00C087);
  static Color greenDim = const Color(0x3300C087);
  static Color red = const Color(0xFFFF4D4F);
  static Color redDim = const Color(0x33FF4D4F);
  static Color accent = const Color(0xFFFFFFFF);
  static Color accentSoft = const Color(0xFFBFBFBF);
  static Color upColor = green;
  static Color downColor = red;
  static int chartTimezoneOffsetHours = 8;

  // Liquid glass tints (theme-aware; avoid gray wash on colored themes).
  static Color glassTop = const Color(0x29FFFFFF);
  static Color glassMid = const Color(0x12FFFFFF);
  static Color glassBottom = const Color(0x08FFFFFF);
  static Color glassBorder = const Color(0x38FFFFFF);
  static Color glassPill = const Color(0x24FFFFFF);
  static Color glassPillBorder = const Color(0x2EFFFFFF);
  static Color glassShadow = const Color(0x73000000);
  static Color glassSpecular = const Color(0x0AFFFFFF);
  static Color glassDivider = const Color(0x14FFFFFF);
  static List<Color> glassBlobs = const [
    Color(0x3300C087),
    Color(0x26FF4D4F),
    Color(0x1A6B8CFF),
    Color(0x14FFFFFF),
  ];
}

class OkxRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const pill = 20.0;
}

class _Palette {
  const _Palette({
    required this.bg,
    required this.surface,
    required this.card,
    required this.elevated,
    required this.border,
    required this.borderLight,
    required this.text,
    required this.muted,
    required this.muted2,
    required this.green,
    required this.red,
    required this.accent,
    required this.accentSoft,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color card;
  final Color elevated;
  final Color border;
  final Color borderLight;
  final Color text;
  final Color muted;
  final Color muted2;
  final Color green;
  final Color red;
  final Color accent;
  final Color accentSoft;
  final bool isDark;
}

class _GlassStyle {
  const _GlassStyle({
    required this.top,
    required this.mid,
    required this.bottom,
    required this.border,
    required this.pill,
    required this.pillBorder,
    required this.shadow,
    required this.specular,
    required this.divider,
    required this.blobs,
  });

  final Color top;
  final Color mid;
  final Color bottom;
  final Color border;
  final Color pill;
  final Color pillBorder;
  final Color shadow;
  final Color specular;
  final Color divider;
  final List<Color> blobs;
}

class AppTheme {
  static const _fontFamily = 'Microsoft YaHei UI';
  static const _fontFallback = ['Microsoft YaHei', 'PingFang SC', 'Noto Sans SC', 'sans-serif'];

  static final _palettes = <AppThemeId, _Palette>{
    AppThemeId.black: const _Palette(
      bg: Color(0xFF000000),
      surface: Color(0xFF121212),
      card: Color(0xFF1A1A1A),
      elevated: Color(0xFF252525),
      border: Color(0xFF2B2B2B),
      borderLight: Color(0x1FFFFFFF),
      text: Color(0xFFFFFFFF),
      muted: Color(0xFF8B8B8B),
      muted2: Color(0xFF5E5E5E),
      green: Color(0xFF00C087),
      red: Color(0xFFFF4D4F),
      accent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFBFBFBF),
      isDark: true,
    ),
    AppThemeId.white: const _Palette(
      bg: Color(0xFFF7F7F8),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      elevated: Color(0xFFF0F0F2),
      border: Color(0xFFE4E4E7),
      borderLight: Color(0x1A000000),
      text: Color(0xFF111111),
      muted: Color(0xFF6B6B6B),
      muted2: Color(0xFF9A9A9A),
      green: Color(0xFF00A870),
      red: Color(0xFFE54548),
      accent: Color(0xFF111111),
      accentSoft: Color(0xFF444444),
      isDark: false,
    ),
    AppThemeId.pink: const _Palette(
      bg: Color(0xFFFFF5F8),
      surface: Color(0xFFFFFBFC),
      card: Color(0xFFFFFFFF),
      elevated: Color(0xFFFFEFF5),
      border: Color(0xFFFFD6E5),
      borderLight: Color(0x1AFF91AF),
      text: Color(0xFF6B4255),
      muted: Color(0xFFB08898),
      muted2: Color(0xFFCEA8B5),
      green: Color(0xFF6BC9A0),
      red: Color(0xFFFF7A9A),
      accent: Color(0xFFFF91AF),
      accentSoft: Color(0xFFFFB3CC),
      isDark: false,
    ),
    AppThemeId.green: const _Palette(
      bg: Color(0xFFF8F6EF),
      surface: Color(0xFFFDFCF7),
      card: Color(0xFFFFFCF6),
      elevated: Color(0xFFEDF3E0),
      border: Color(0xFFDDE8CA),
      borderLight: Color(0x1A94B86E),
      text: Color(0xFF3F4D35),
      muted: Color(0xFF7A8F68),
      muted2: Color(0xFF9EAE8C),
      green: Color(0xFF7FAF58),
      red: Color(0xFFD9796A),
      accent: Color(0xFF94B86E),
      accentSoft: Color(0xFFB5CF94),
      isDark: false,
    ),
  };

  static const _glass = <AppThemeId, _GlassStyle>{
    AppThemeId.black: _GlassStyle(
      top: Color(0x29FFFFFF),
      mid: Color(0x12FFFFFF),
      bottom: Color(0x08FFFFFF),
      border: Color(0x38FFFFFF),
      pill: Color(0x24FFFFFF),
      pillBorder: Color(0x2EFFFFFF),
      shadow: Color(0x73000000),
      specular: Color(0x0AFFFFFF),
      divider: Color(0x14FFFFFF),
      blobs: [Color(0x3300C087), Color(0x26FF4D4F), Color(0x1A6B8CFF), Color(0x14FFFFFF)],
    ),
    AppThemeId.white: _GlassStyle(
      top: Color(0xD9FFFFFF),
      mid: Color(0xA6F4F4F5),
      bottom: Color(0x80E4E4E7),
      border: Color(0x66E4E4E7),
      pill: Color(0xB3FFFFFF),
      pillBorder: Color(0x80E4E4E7),
      shadow: Color(0x1A111111),
      specular: Color(0x33FFFFFF),
      divider: Color(0x1A111111),
      blobs: [Color(0x1A00A870), Color(0x14E54548), Color(0x0F6B8CFF), Color(0x0A000000)],
    ),
    AppThemeId.pink: _GlassStyle(
      top: Color(0xCCFFFBFC),
      mid: Color(0xA6FFEDF3),
      bottom: Color(0x80FFE4EC),
      border: Color(0x66FFD6E5),
      pill: Color(0xB3FFF5F8),
      pillBorder: Color(0x73FFCCD9),
      shadow: Color(0x266B4255),
      specular: Color(0x40FFFFFF),
      divider: Color(0x1AFFD6E5),
      blobs: [Color(0x33FF91AF), Color(0x29FFB3CC), Color(0x26FFEFF5), Color(0x1AFFD6E5)],
    ),
    AppThemeId.green: _GlassStyle(
      top: Color(0xCCFFFCF6),
      mid: Color(0xA6F2F6EA),
      bottom: Color(0x80E8F0DC),
      border: Color(0x66DDE8CA),
      pill: Color(0xB3F5F8EF),
      pillBorder: Color(0x73C5D9A8),
      shadow: Color(0x263F4D35),
      specular: Color(0x40FFFFFF),
      divider: Color(0x1ADDE8CA),
      blobs: [Color(0x33B5CF94), Color(0x2994B86E), Color(0x26EDF3E0), Color(0x1ADDE8CA)],
    ),
  };

  static void applySettings(AppSettings settings) {
    final p = _palettes[settings.themeId] ?? _palettes[AppThemeId.black]!;
    final g = _glass[settings.themeId] ?? _glass[AppThemeId.black]!;
    AppColors.bg = p.bg;
    AppColors.surface = p.surface;
    AppColors.card = p.card;
    AppColors.elevated = p.elevated;
    AppColors.border = p.border;
    AppColors.borderLight = p.borderLight;
    AppColors.text = p.text;
    AppColors.muted = p.muted;
    AppColors.muted2 = p.muted2;
    AppColors.green = p.green;
    AppColors.red = p.red;
    AppColors.accent = p.accent;
    AppColors.accentSoft = p.accentSoft;
    AppColors.greenDim = p.green.withValues(alpha: 0.2);
    AppColors.redDim = p.red.withValues(alpha: 0.2);
    AppColors.chartTimezoneOffsetHours = settings.timezone.offsetHours;

    final greenUp = settings.pnlColorMode == PnlColorMode.greenUp;
    AppColors.upColor = greenUp ? p.green : p.red;
    AppColors.downColor = greenUp ? p.red : p.green;

    AppColors.glassTop = g.top;
    AppColors.glassMid = g.mid;
    AppColors.glassBottom = g.bottom;
    AppColors.glassBorder = g.border;
    AppColors.glassPill = g.pill;
    AppColors.glassPillBorder = g.pillBorder;
    AppColors.glassShadow = g.shadow;
    AppColors.glassSpecular = g.specular;
    AppColors.glassDivider = g.divider;
    AppColors.glassBlobs = g.blobs;
  }

  static TextStyle _style(double size, {FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
      height: 1.25,
    );
  }

  static ThemeData current() {
    final p = _palettes.values.firstWhere(
      (e) => e.bg == AppColors.bg,
      orElse: () => _palettes[AppThemeId.black]!,
    );
    final base = p.isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: (p.isDark ? ColorScheme.dark() : ColorScheme.light()).copyWith(
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.green,
        error: AppColors.red,
      ),
      splashColor: AppColors.borderLight,
      highlightColor: AppColors.borderLight,
      textTheme: TextTheme(
        displayLarge: _style(28, weight: FontWeight.w700),
        displayMedium: _style(22, weight: FontWeight.w700),
        displaySmall: _style(18, weight: FontWeight.w600),
        headlineMedium: _style(16, weight: FontWeight.w600),
        headlineSmall: _style(15, weight: FontWeight.w600),
        titleLarge: _style(14, weight: FontWeight.w600),
        titleMedium: _style(13, weight: FontWeight.w500),
        titleSmall: _style(12, weight: FontWeight.w500),
        bodyLarge: _style(13),
        bodyMedium: _style(12),
        bodySmall: _style(11, color: AppColors.muted),
        labelLarge: _style(12, weight: FontWeight.w600),
        labelMedium: _style(11),
        labelSmall: _style(10, color: AppColors.muted),
      ),
      iconTheme: IconThemeData(size: DisplayConfig.iconSize, color: AppColors.text),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 48,
        titleTextStyle: _style(16, weight: FontWeight.w600),
        iconTheme: IconThemeData(size: DisplayConfig.iconSize, color: AppColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OkxRadius.md),
          side: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.elevated,
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OkxRadius.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OkxRadius.pill),
          borderSide: BorderSide(color: AppColors.muted2, width: 0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OkxRadius.pill),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        labelStyle: _style(11, color: AppColors.muted),
        hintStyle: _style(12, color: AppColors.muted2),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.muted,
        labelStyle: _style(13, weight: FontWeight.w600),
        unselectedLabelStyle: _style(13, weight: FontWeight.w400, color: AppColors.muted),
        dividerColor: AppColors.border,
        dividerHeight: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: _style(12),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OkxRadius.md)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: p.isDark ? Colors.white : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OkxRadius.md)),
          textStyle: _style(13, weight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OkxRadius.md)),
          textStyle: _style(11, weight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 34),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          textStyle: _style(12, weight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: _style(11),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.text,
        unselectedItemColor: AppColors.muted2,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _style(10, weight: FontWeight.w600),
        unselectedLabelStyle: _style(10, color: AppColors.muted2),
        selectedIconTheme: const IconThemeData(size: 22),
        unselectedIconTheme: const IconThemeData(size: 20),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 0.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accentSoft,
        strokeWidth: 2,
      ),
    );
  }

  @Deprecated('Use AppTheme.current()')
  static ThemeData dark() => current();
}
