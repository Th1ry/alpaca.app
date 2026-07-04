import 'alpaca_config.dart';

enum AppThemeId { black, white, pink, green }

enum AppLanguage { zh, en }

/// Green-up / red-down (CN) vs red-up / green-down.
enum PnlColorMode { greenUp, redUp }

enum AppTimezone {
  shanghai('Asia/Shanghai', 8, 'tzShanghai'),
  newYork('America/New_York', -5, 'tzNewYork'),
  losAngeles('America/Los_Angeles', -8, 'tzLosAngeles'),
  utc('UTC', 0, 'tzUtc');

  const AppTimezone(this.id, this.offsetHours, this.labelKey);
  final String id;
  final int offsetHours;
  final String labelKey;

  static AppTimezone fromId(String? id) {
    for (final tz in values) {
      if (tz.id == id) return tz;
    }
    return shanghai;
  }
}

class AppSettings {
  const AppSettings({
    required this.alpaca,
    required this.themeId,
    required this.language,
    required this.pnlColorMode,
    required this.timezone,
    this.depthApiUrl = '',
    this.autoTranslateNews = false,
  });

  final AlpacaCredentials alpaca;
  final AppThemeId themeId;
  final AppLanguage language;
  final PnlColorMode pnlColorMode;
  final AppTimezone timezone;

  /// Optional HTTPS template for extended depth (2–5). Use `{symbol}` placeholder.
  final String depthApiUrl;

  /// When language is zh, translate English news via online service.
  final bool autoTranslateNews;

  factory AppSettings.defaults() => AppSettings(
        alpaca: AlpacaCredentials.defaults(),
        themeId: AppThemeId.black,
        language: AppLanguage.zh,
        pnlColorMode: PnlColorMode.greenUp,
        timezone: AppTimezone.shanghai,
      );

  AlpacaEnv get alpacaEnv => alpacaEnvFromUrl(alpaca.apiUrl);

  AppSettings copyWith({
    AlpacaCredentials? alpaca,
    AppThemeId? themeId,
    AppLanguage? language,
    PnlColorMode? pnlColorMode,
    AppTimezone? timezone,
    String? depthApiUrl,
    bool? autoTranslateNews,
  }) {
    return AppSettings(
      alpaca: alpaca ?? this.alpaca,
      themeId: themeId ?? this.themeId,
      language: language ?? this.language,
      pnlColorMode: pnlColorMode ?? this.pnlColorMode,
      timezone: timezone ?? this.timezone,
      depthApiUrl: depthApiUrl ?? this.depthApiUrl,
      autoTranslateNews: autoTranslateNews ?? this.autoTranslateNews,
    );
  }
}
