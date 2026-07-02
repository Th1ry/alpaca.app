import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_update_config.dart';

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.version,
    required this.build,
    this.androidUrl,
    this.windowsUrl,
    this.notes = '',
    this.minBuild = 0,
  });

  final String version;
  final int build;
  final String? androidUrl;
  final String? windowsUrl;
  final String notes;
  final int minBuild;

  factory AppUpdateManifest.fromJson(Map<String, dynamic> j) => AppUpdateManifest(
        version: (j['version'] as String? ?? '').trim(),
        build: _parseInt(j['build']),
        androidUrl: (j['android_url'] as String?)?.trim(),
        windowsUrl: (j['windows_url'] as String?)?.trim(),
        notes: (j['notes'] as String? ?? '').trim(),
        minBuild: _parseInt(j['min_build']),
      );

  static int _parseInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  bool forceBelow(int currentBuild) => minBuild > 0 && currentBuild < minBuild;

  String? downloadUrlForCurrentPlatform() {
    if (!kIsWeb && Platform.isAndroid) return _nonEmpty(androidUrl);
    if (!kIsWeb && Platform.isWindows) return _nonEmpty(windowsUrl);
    return _nonEmpty(androidUrl) ?? _nonEmpty(windowsUrl);
  }

  String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.manifest,
    required this.currentBuild,
    required this.forceUpdate,
  });

  final AppUpdateManifest manifest;
  final int currentBuild;
  final bool forceUpdate;
}

enum AppUpdateInstallPhase { idle, downloading, installing, done, failed }

class AppUpdateInstallProgress {
  const AppUpdateInstallProgress({
    required this.phase,
    this.progress,
    this.message,
  });

  final AppUpdateInstallPhase phase;
  final double? progress;
  final String? message;
}

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const _dismissedBuildKey = 'app_update_dismissed_build';
  static const _lastCheckKey = 'app_update_last_check_ms';

  bool get isEnabled => AppUpdateConfig.manifestUrl.trim().isNotEmpty;

  Future<PackageInfo> packageInfo() => PackageInfo.fromPlatform();

  Future<AppUpdateInfo?> checkForUpdate({bool respectDismiss = true}) async {
    final url = AppUpdateConfig.manifestUrl.trim();
    if (url.isEmpty) return null;

    final pkg = await packageInfo();
    final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;
    final manifest = await _fetchManifest(url);

    if (manifest.build <= currentBuild) return null;

    if (respectDismiss && !manifest.forceBelow(currentBuild)) {
      final dismissed = await dismissedBuild();
      if (manifest.build <= dismissed) return null;
    }

    return AppUpdateInfo(
      manifest: manifest,
      currentBuild: currentBuild,
      forceUpdate: manifest.forceBelow(currentBuild),
    );
  }

  Future<bool> shouldAutoCheck() async {
    if (!isEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastCheckKey);
    if (last == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= AppUpdateConfig.autoCheckIntervalHours * 3600 * 1000;
  }

  Future<void> markAutoChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<int> dismissedBuild() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dismissedBuildKey) ?? 0;
  }

  Future<void> dismissVersion(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissedBuildKey, build);
  }

  Future<AppUpdateManifest> _fetchManifest(String url) async {
    final resp = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    final body = resp.data;
    if (body == null || body.isEmpty) throw Exception('empty manifest');
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) throw Exception('invalid manifest json');
    return AppUpdateManifest.fromJson(json);
  }

  Stream<AppUpdateInstallProgress> installUpdate(AppUpdateInfo info) async* {
    final url = info.manifest.downloadUrlForCurrentPlatform();
    if (url == null || url.isEmpty) {
      yield const AppUpdateInstallProgress(
        phase: AppUpdateInstallPhase.failed,
        message: 'no_download_url',
      );
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      yield* _installAndroid(url);
      return;
    }

    yield const AppUpdateInstallProgress(phase: AppUpdateInstallPhase.downloading);
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    yield AppUpdateInstallProgress(
      phase: ok ? AppUpdateInstallPhase.done : AppUpdateInstallPhase.failed,
      message: ok ? null : 'launch_failed',
    );
  }

  Stream<AppUpdateInstallProgress> _installAndroid(String url) async* {
    try {
      yield const AppUpdateInstallProgress(
        phase: AppUpdateInstallPhase.downloading,
        progress: 0,
      );
      await for (final event in OtaUpdate().execute(
        url,
        destinationFilename: 'alpaca_options_update.apk',
      )) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            yield AppUpdateInstallProgress(
              phase: AppUpdateInstallPhase.downloading,
              progress: _otaProgress(event.value),
            );
          case OtaStatus.INSTALLING:
            yield const AppUpdateInstallProgress(phase: AppUpdateInstallPhase.installing);
          case OtaStatus.INSTALLATION_DONE:
            yield const AppUpdateInstallProgress(phase: AppUpdateInstallPhase.done);
            return;
          case OtaStatus.ALREADY_RUNNING_ERROR:
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
          case OtaStatus.CANCELED:
          case OtaStatus.INSTALLATION_ERROR:
            yield AppUpdateInstallProgress(
              phase: AppUpdateInstallPhase.failed,
              message: event.status.name,
            );
            return;
        }
      }
      yield const AppUpdateInstallProgress(phase: AppUpdateInstallPhase.done);
    } catch (e) {
      yield AppUpdateInstallProgress(
        phase: AppUpdateInstallPhase.failed,
        message: '$e',
      );
    }
  }

  double? _otaProgress(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble() / 100.0;
    return (double.tryParse(value.toString()) ?? 0) / 100.0;
  }
}
