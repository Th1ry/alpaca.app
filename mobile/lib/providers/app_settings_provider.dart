import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../core/alpaca_config.dart';

import '../core/app_settings.dart';

import '../core/depth_api_config.dart';

import '../core/strings.dart';

import '../core/theme/app_theme.dart';

const _kAlpacaUrl = 'alpaca_api_url';

const _kAlpacaKey = 'alpaca_api_key';

const _kAlpacaSecret = 'alpaca_api_secret';

const _kTheme = 'app_theme';

const _kLanguage = 'app_language';

const _kPnlColor = 'pnl_color_mode';

const _kTimezone = 'app_timezone';

const _kDepthApiUrl = 'depth_api_url';



final appSettingsProvider =

    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {

  return AppSettingsNotifier();

});



class AppSettingsNotifier extends StateNotifier<AppSettings> {

  AppSettingsNotifier() : super(AppSettings.defaults());



  Future<void> load() async {

    final p = await SharedPreferences.getInstance();

    state = AppSettings(

      alpaca: AlpacaCredentials(

        apiUrl: _nonEmptyUrl(p.getString(_kAlpacaUrl)) ?? AlpacaCredentials.paperUrl,

        apiKey: p.getString(_kAlpacaKey) ?? '',

        apiSecret: p.getString(_kAlpacaSecret) ?? '',

      ),

      themeId: _parseEnum(AppThemeId.values, p.getString(_kTheme), AppThemeId.black),

      language: _parseEnum(AppLanguage.values, p.getString(_kLanguage), AppLanguage.zh),

      pnlColorMode: _parseEnum(PnlColorMode.values, p.getString(_kPnlColor), PnlColorMode.greenUp),

      timezone: AppTimezone.fromId(p.getString(_kTimezone)),

      depthApiUrl: p.getString(_kDepthApiUrl) ?? DepthApiConfig.urlTemplate,

    );

    _applyRuntime(state);

  }



  String? _nonEmptyUrl(String? url) {

    if (url == null || url.trim().isEmpty) return null;

    return url.trim();

  }



  T _parseEnum<T extends Enum>(List<T> values, String? name, T fallback) {

    if (name == null) return fallback;

    for (final v in values) {

      if (v.name == name) return v;

    }

    return fallback;

  }



  void _applyRuntime(AppSettings s) {

    AppTheme.applySettings(s);

    S.setLanguage(s.language);

  }



  Future<void> saveAlpaca(AlpacaCredentials alpaca) async {

    final p = await SharedPreferences.getInstance();

    final url = _nonEmptyUrl(alpaca.apiUrl) ?? AlpacaCredentials.paperUrl;

    await p.setString(_kAlpacaUrl, url);

    await p.setString(_kAlpacaKey, alpaca.apiKey);

    await p.setString(_kAlpacaSecret, alpaca.apiSecret);

    state = state.copyWith(alpaca: alpaca.copyWith(apiUrl: url));

  }



  Future<void> saveDepthApiUrl(String url) async {

    final p = await SharedPreferences.getInstance();

    final trimmed = url.trim();

    await p.setString(_kDepthApiUrl, trimmed);

    state = state.copyWith(depthApiUrl: trimmed);

  }



  Future<void> updatePreferences({

    AppThemeId? themeId,

    AppLanguage? language,

    PnlColorMode? pnlColorMode,

    AppTimezone? timezone,

  }) async {

    final p = await SharedPreferences.getInstance();

    if (themeId != null) await p.setString(_kTheme, themeId.name);

    if (language != null) await p.setString(_kLanguage, language.name);

    if (pnlColorMode != null) await p.setString(_kPnlColor, pnlColorMode.name);

    if (timezone != null) await p.setString(_kTimezone, timezone.id);



    state = state.copyWith(

      themeId: themeId,

      language: language,

      pnlColorMode: pnlColorMode,

      timezone: timezone,

    );

    _applyRuntime(state);

  }

}

