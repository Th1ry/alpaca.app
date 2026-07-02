import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/alpaca_config.dart';
import '../../core/app_settings.dart';
import '../../core/app_update_config.dart';

import '../../core/strings.dart';

import '../../core/theme/app_theme.dart';

import '../../providers/alpaca_connection_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/app_update_provider.dart';

import '../../shared/widgets/floating_capsule_nav.dart';
import '../../shared/widgets/okx_ui.dart';
import 'app_update_dialog.dart';



class SettingsScreen extends ConsumerStatefulWidget {

  const SettingsScreen({super.key});



  @override

  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();

}



class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  final _keyCtrl = TextEditingController();

  final _secretCtrl = TextEditingController();

  final _depthCtrl = TextEditingController();

  final _updateManifestCtrl = TextEditingController();

  AlpacaEnv _env = AlpacaEnv.paper;

  var _fieldsReady = false;
  PackageInfo? _packageInfo;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadApiFields());
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }



  @override

  void dispose() {

    _keyCtrl.dispose();

    _secretCtrl.dispose();

    _depthCtrl.dispose();

    _updateManifestCtrl.dispose();

    super.dispose();

  }



  void _loadApiFields() {

    if (!mounted || _fieldsReady) return;

    final s = ref.read(appSettingsProvider);

    _env = s.alpacaEnv;

    _keyCtrl.text = s.alpaca.apiKey;

    _secretCtrl.text = s.alpaca.apiSecret;

    _depthCtrl.text = s.depthApiUrl;

    _updateManifestCtrl.text = s.updateManifestUrl;

    setState(() => _fieldsReady = true);

  }



  AlpacaCredentials _draftCreds() => AlpacaCredentials(

        apiUrl: alpacaUrlForEnv(_env),

        apiKey: _keyCtrl.text.trim(),

        apiSecret: _secretCtrl.text.trim(),

      );



  Future<void> _testConnection() async {
    final creds = _draftCreds();
    final ok = await ref.read(alpacaConnectionProvider.notifier).verify(
          creds: creds,
          persistOnSuccess: true,
        );
    if (!mounted) return;
    final conn = ref.read(alpacaConnectionProvider);
    _showApiSnack(
      ok ? S.apiSaveSuccess : S.apiStatusFailed,
      ok: ok,
      subtitle: ok ? conn.detail : conn.error,
    );
  }



  Future<void> _saveApi() async {
    final creds = _draftCreds();
    if (!creds.isConfigured) {
      _showApiSnack(S.apiNotConfigured, ok: false);
      return;
    }

    final ok = await ref.read(alpacaConnectionProvider.notifier).save(creds);
    await ref.read(appSettingsProvider.notifier).saveDepthApiUrl(_depthCtrl.text);
    if (!mounted) return;
    final conn = ref.read(alpacaConnectionProvider);
    _showApiSnack(
      ok ? S.apiSaveSuccess : S.apiSaveFailed,
      ok: ok,
      subtitle: ok ? conn.detail : conn.error,
    );
  }



  void _showApiSnack(String title, {required bool ok, String? subtitle}) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        backgroundColor: ok ? AppColors.green.withValues(alpha: 0.92) : AppColors.red.withValues(alpha: 0.92),

        behavior: SnackBarBehavior.floating,

        duration: const Duration(seconds: 3),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),

            if (subtitle != null && subtitle.isNotEmpty) ...[

              const SizedBox(height: 4),

              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),

            ],

          ],

        ),

      ),

    );

  }



  Widget _buildConnectionBanner(AlpacaConnectionView conn) {

    late Color bg;

    late Color fg;

    late IconData icon;

    late String title;

    String? subtitle;

    switch (conn.phase) {

      case AlpacaConnPhase.testing:

        bg = AppColors.accent.withValues(alpha: 0.15);

        fg = AppColors.accent;

        icon = Icons.sync;

        title = S.apiStatusTesting;

      case AlpacaConnPhase.ok:

        bg = AppColors.green.withValues(alpha: 0.12);

        fg = AppColors.green;

        icon = Icons.check_circle_outline;

        title = S.apiStatusConnected;

        subtitle = conn.detail;

      case AlpacaConnPhase.fail:

        bg = AppColors.red.withValues(alpha: 0.12);

        fg = AppColors.red;

        icon = Icons.error_outline;

        title = S.apiStatusFailed;

        subtitle = conn.error;

      case AlpacaConnPhase.empty:

        bg = AppColors.elevated;

        fg = AppColors.muted;

        icon = Icons.info_outline;

        title = S.apiNotConfigured;

      case AlpacaConnPhase.idle:

        bg = AppColors.elevated;

        fg = AppColors.muted;

        icon = Icons.cloud_outlined;

        title = S.apiTestConnection;

    }

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(

        color: bg,

        borderRadius: BorderRadius.circular(OkxRadius.lg),

        border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.5),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          if (conn.phase == AlpacaConnPhase.testing || conn.busy)

            Padding(

              padding: const EdgeInsets.only(top: 2),

              child: SizedBox(

                width: 18,

                height: 18,

                child: CircularProgressIndicator(strokeWidth: 2, color: fg),

              ),

            )

          else

            Icon(icon, size: 18, color: fg),

          const SizedBox(width: 10),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),

                if (subtitle != null && subtitle.isNotEmpty) ...[

                  const SizedBox(height: 3),

                  Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.35)),

                ],

              ],

            ),

          ),

        ],

      ),

    );

  }



  void _showPrefSaved() {

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(S.settingsSaved), duration: const Duration(seconds: 3)),

    );

  }



  Future<void> _checkForUpdate({bool showUpToDate = true}) async {
    await ref.read(appSettingsProvider.notifier).saveUpdateManifestUrl(_updateManifestCtrl.text);
    final info = await ref.read(appUpdateProvider.notifier).check(respectDismiss: false);
    if (!mounted) return;
    final phase = ref.read(appUpdateProvider).phase;
    if (info != null) {
      await showAppUpdateDialog(
        context,
        info: info,
        onLater: () => ref.read(appUpdateProvider.notifier).dismiss(info),
        onInstall: () => ref.read(appUpdateServiceProvider).installUpdate(info),
      );
      return;
    }
    if (!showUpToDate) return;
    final msg = switch (phase) {
      AppUpdateCheckPhase.disabled => S.updateDisabled,
      AppUpdateCheckPhase.failed => '${S.updateCheckFailed}: ${ref.read(appUpdateProvider).error ?? ''}',
      AppUpdateCheckPhase.upToDate => S.updateUpToDate,
      _ => S.updateCheckFailed,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }



  @override

  Widget build(BuildContext context) {

    final settings = ref.watch(appSettingsProvider);
    final conn = ref.watch(alpacaConnectionProvider);
    final busy = conn.busy;
    final updateState = ref.watch(appUpdateProvider);



    return Scaffold(

      backgroundColor: AppColors.bg,

      appBar: AppBar(title: Text(S.settings)),

      body: ListView(

        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          32 + FloatingCapsuleNav.overlayInset(context),
        ),

        children: [

          _SectionTitle(title: S.apiSection),

          const SizedBox(height: 8),

          OkxPanel(

            padding: const EdgeInsets.all(14),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                Row(

                  children: [

                    Icon(Icons.lock_outline, size: 16, color: AppColors.muted),

                    const SizedBox(width: 6),

                    Expanded(

                      child: Text(

                        S.apiLocalOnly,

                        style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.35),

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 14),

                _buildConnectionBanner(conn),

                const SizedBox(height: 14),

                OkxCapsuleSwitch(

                  leftLabel: S.alpacaEnvPaper,

                  rightLabel: S.alpacaEnvLive,

                  showRight: _env == AlpacaEnv.live,

                  leftPillColor: AppColors.accent,

                  rightPillColor: AppColors.red.withValues(alpha: 0.85),

                  onChanged: (live) => setState(() => _env = live ? AlpacaEnv.live : AlpacaEnv.paper),

                  height: 38,

                ),

                const SizedBox(height: 6),

                Align(

                  alignment: Alignment.centerLeft,

                  child: Text(

                    S.apiUrlAuto,

                    style: TextStyle(fontSize: 10, color: AppColors.muted),

                  ),

                ),

                const SizedBox(height: 2),

                SelectableText(

                  alpacaUrlForEnv(_env),

                  style: TextStyle(fontSize: 11, color: AppColors.accentSoft, height: 1.3),

                ),

                const SizedBox(height: 14),

                TextField(

                  controller: _keyCtrl,

                  decoration: InputDecoration(labelText: S.alpacaApiKey),

                  autocorrect: false,

                  textInputAction: TextInputAction.next,

                ),

                const SizedBox(height: 10),

                TextField(

                  controller: _secretCtrl,

                  decoration: InputDecoration(labelText: S.alpacaApiSecret),

                  obscureText: true,

                  autocorrect: false,

                ),

                const SizedBox(height: 10),

                TextField(

                  controller: _depthCtrl,

                  decoration: InputDecoration(

                    labelText: S.depthApiUrl,

                    hintText: 'https://api.example.com/depth/{symbol}',

                    helperText: S.depthApiHint,

                    helperMaxLines: 3,

                  ),

                  autocorrect: false,

                  keyboardType: TextInputType.url,

                ),

                const SizedBox(height: 14),

                Row(

                  children: [

                    Expanded(

                      child: OutlinedButton(

                        onPressed: busy ? null : () => _testConnection(),

                        child: Text(S.apiTestConnection),

                      ),

                    ),

                    const SizedBox(width: 10),

                    Expanded(

                      child: FilledButton(

                        onPressed: busy ? null : _saveApi,

                        child: busy

                            ? const SizedBox(

                                width: 18,

                                height: 18,

                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),

                              )

                            : Text(S.save),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

          const SizedBox(height: 28),

          _SectionTitle(title: S.preferences),

          const SizedBox(height: 8),

          OkxPanel(

            padding: const EdgeInsets.all(14),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                _PrefLabel(S.language),

                const SizedBox(height: 8),

                OkxSegmentRow(

                  options: [

                    (AppLanguage.zh.name, S.languageZh),

                    (AppLanguage.en.name, S.languageEn),

                  ],

                  selected: settings.language.name,

                  onSelect: (v) async {

                    await ref.read(appSettingsProvider.notifier).updatePreferences(

                          language: AppLanguage.values.byName(v),

                        );

                    _showPrefSaved();

                  },

                ),

                const SizedBox(height: 18),

                _PrefLabel(S.themeLabel),

                const SizedBox(height: 8),

                _ThemePicker(

                  selected: settings.themeId,

                  onSelect: (t) async {

                    await ref.read(appSettingsProvider.notifier).updatePreferences(themeId: t);

                    _showPrefSaved();

                  },

                ),

                const SizedBox(height: 18),

                _PrefLabel(S.pnlColors),

                const SizedBox(height: 8),

                OkxSegmentRow(

                  options: [

                    (PnlColorMode.greenUp.name, S.pnlGreenUp),

                    (PnlColorMode.redUp.name, S.pnlRedUp),

                  ],

                  selected: settings.pnlColorMode.name,

                  onSelect: (v) async {

                    await ref.read(appSettingsProvider.notifier).updatePreferences(

                          pnlColorMode: PnlColorMode.values.byName(v),

                        );

                    _showPrefSaved();

                  },

                ),

                const SizedBox(height: 18),

                _PrefLabel(S.timezone),

                const SizedBox(height: 8),

                ...AppTimezone.values.map(

                  (tz) => _TimezoneTile(

                    label: S.timezoneLabel(tz),

                    selected: settings.timezone == tz,

                    onTap: () async {

                      await ref.read(appSettingsProvider.notifier).updatePreferences(timezone: tz);

                      _showPrefSaved();

                    },

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(height: 28),

          Center(

            child: Column(

              children: [

                Text(

                  _packageInfo == null

                      ? ''

                      : '${S.appVersion} ${_packageInfo!.version} (${_packageInfo!.buildNumber})',

                  style: TextStyle(fontSize: 11, color: AppColors.muted2, height: 1.4),

                ),

                const SizedBox(height: 10),

                TextField(

                  controller: _updateManifestCtrl,

                  decoration: InputDecoration(

                    labelText: S.updateManifestUrl,

                    hintText: AppUpdateConfig.defaultManifestUrl,

                    helperText: S.updateManifestHint,

                    helperMaxLines: 2,

                  ),

                  autocorrect: false,

                  keyboardType: TextInputType.url,

                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(

                  onPressed: updateState.phase == AppUpdateCheckPhase.checking

                      ? null

                      : () => _checkForUpdate(),

                  icon: updateState.phase == AppUpdateCheckPhase.checking

                      ? SizedBox(

                          width: 16,

                          height: 16,

                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),

                        )

                      : const Icon(Icons.system_update_alt, size: 18),

                  label: Text(S.checkForUpdate),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}



class _SectionTitle extends StatelessWidget {

  const _SectionTitle({required this.title});



  final String title;



  @override

  Widget build(BuildContext context) {

    return Text(

      title,

      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),

    );

  }

}



class _PrefLabel extends StatelessWidget {

  const _PrefLabel(this.text);



  final String text;



  @override

  Widget build(BuildContext context) {

    return Text(text, style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500));

  }

}



class _ThemePicker extends StatelessWidget {

  const _ThemePicker({required this.selected, required this.onSelect});



  final AppThemeId selected;

  final ValueChanged<AppThemeId> onSelect;



  static const _swatches = <AppThemeId, List<Color>>{

    AppThemeId.black: [Color(0xFF000000), Color(0xFF2B2B2B), Color(0xFFFFFFFF)],

    AppThemeId.white: [Color(0xFFF7F7F8), Color(0xFFE4E4E7), Color(0xFF111111)],

    AppThemeId.pink: [Color(0xFFFFF5F8), Color(0xFFFF91AF), Color(0xFF6B4255)],

    AppThemeId.green: [Color(0xFFF8F6EF), Color(0xFF94B86E), Color(0xFF3F4D35)],

  };



  @override

  Widget build(BuildContext context) {

    return Row(

      children: [

        for (final id in AppThemeId.values) ...[

          Expanded(

            child: _ThemeChip(

              label: S.themeName(id),

              colors: _swatches[id]!,

              selected: selected == id,

              onTap: () => onSelect(id),

            ),

          ),

          if (id != AppThemeId.values.last) const SizedBox(width: 8),

        ],

      ],

    );

  }

}



class _ThemeChip extends StatelessWidget {

  const _ThemeChip({

    required this.label,

    required this.colors,

    required this.selected,

    required this.onTap,

  });



  final String label;

  final List<Color> colors;

  final bool selected;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(OkxRadius.md),

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 200),

          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(OkxRadius.md),

            border: Border.all(

              color: selected ? AppColors.accent : AppColors.border,

              width: selected ? 1.2 : 0.5,

            ),

            color: selected ? AppColors.elevated : Colors.transparent,

          ),

          child: Column(

            children: [

              Row(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  for (final c in colors)

                    Container(

                      width: 10,

                      height: 10,

                      margin: const EdgeInsets.symmetric(horizontal: 1),

                      decoration: BoxDecoration(

                        color: c,

                        shape: BoxShape.circle,

                        border: Border.all(color: AppColors.border, width: 0.5),

                      ),

                    ),

                ],

              ),

              const SizedBox(height: 4),

              Text(

                label,

                style: TextStyle(

                  fontSize: 11,

                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,

                  color: selected ? AppColors.text : AppColors.muted,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _TimezoneTile extends StatelessWidget {

  const _TimezoneTile({

    required this.label,

    required this.selected,

    required this.onTap,

  });



  final String label;

  final bool selected;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 6),

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          onTap: onTap,

          borderRadius: BorderRadius.circular(OkxRadius.md),

          child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

            decoration: BoxDecoration(

              borderRadius: BorderRadius.circular(OkxRadius.md),

              color: selected ? AppColors.elevated : Colors.transparent,

              border: Border.all(

                color: selected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,

                width: 0.5,

              ),

            ),

            child: Row(

              children: [

                Icon(

                  selected ? Icons.radio_button_checked : Icons.radio_button_off,

                  size: 18,

                  color: selected ? AppColors.accent : AppColors.muted2,

                ),

                const SizedBox(width: 10),

                Expanded(

                  child: Text(

                    label,

                    style: TextStyle(

                      fontSize: 12,

                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,

                      color: selected ? AppColors.text : AppColors.muted,

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}
