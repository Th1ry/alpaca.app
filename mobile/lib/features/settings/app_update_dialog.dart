import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateInfo info,
  required Future<void> Function() onLater,
  required Stream<AppUpdateInstallProgress> Function() onInstall,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (ctx) => _AppUpdateDialog(
      info: info,
      onLater: onLater,
      onInstall: onInstall,
    ),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({
    required this.info,
    required this.onLater,
    required this.onInstall,
  });

  final AppUpdateInfo info;
  final Future<void> Function() onLater;
  final Stream<AppUpdateInstallProgress> Function() onInstall;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  AppUpdateInstallPhase _phase = AppUpdateInstallPhase.idle;
  double? _progress;
  String? _error;

  Future<void> _startInstall() async {
    setState(() {
      _phase = AppUpdateInstallPhase.downloading;
      _progress = 0;
      _error = null;
    });
    await for (final p in widget.onInstall()) {
      if (!mounted) return;
      setState(() {
        _phase = p.phase;
        _progress = p.progress;
        _error = p.message;
      });
      if (p.phase == AppUpdateInstallPhase.done) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (p.phase == AppUpdateInstallPhase.failed) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final busy = _phase == AppUpdateInstallPhase.downloading ||
        _phase == AppUpdateInstallPhase.installing;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(S.updateAvailableTitle(info.manifest.version)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info.manifest.notes.isNotEmpty)
              Text(info.manifest.notes, style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45))
            else
              Text(S.updateAvailableBody, style: TextStyle(color: AppColors.muted, fontSize: 13)),
            if (busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _phase == AppUpdateInstallPhase.installing ? S.updateInstalling : S.updateDownloading,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.red)),
            ],
          ],
        ),
      ),
      actions: [
        if (!info.forceUpdate && !busy)
          TextButton(
            onPressed: () async {
              await widget.onLater();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(S.updateLater),
          ),
        if (!busy)
          FilledButton(
            onPressed: _startInstall,
            child: Text(S.updateNow),
          ),
      ],
    );
  }
}

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key, required this.version, required this.onTap});

  final String version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OkxRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(OkxRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.system_update_alt, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.updateBanner(version),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentSoft),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
