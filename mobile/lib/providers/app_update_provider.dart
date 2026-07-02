import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_update_service.dart';

enum AppUpdateCheckPhase { idle, checking, upToDate, available, failed, disabled }

class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdateCheckPhase.idle,
    this.info,
    this.error,
  });

  final AppUpdateCheckPhase phase;
  final AppUpdateInfo? info;
  final String? error;

  AppUpdateState copyWith({
    AppUpdateCheckPhase? phase,
    AppUpdateInfo? info,
    String? error,
    bool clearInfo = false,
    bool clearError = false,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      info: clearInfo ? null : (info ?? this.info),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) => AppUpdateService());

final appUpdateProvider = StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  return AppUpdateNotifier(ref.read(appUpdateServiceProvider));
});

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier(this._service) : super(const AppUpdateState());

  final AppUpdateService _service;

  Future<AppUpdateInfo?> check({bool respectDismiss = true, bool markAuto = false}) async {
    if (!_service.isEnabled) {
      state = state.copyWith(phase: AppUpdateCheckPhase.disabled, clearInfo: true, clearError: true);
      return null;
    }
    state = state.copyWith(phase: AppUpdateCheckPhase.checking, clearError: true);
    try {
      if (markAuto) await _service.markAutoChecked();
      final info = await _service.checkForUpdate(respectDismiss: respectDismiss);
      if (info == null) {
        state = state.copyWith(phase: AppUpdateCheckPhase.upToDate, clearInfo: true);
        return null;
      }
      state = state.copyWith(phase: AppUpdateCheckPhase.available, info: info);
      return info;
    } catch (e) {
      state = state.copyWith(phase: AppUpdateCheckPhase.failed, error: '$e', clearInfo: true);
      return null;
    }
  }

  Future<void> dismiss(AppUpdateInfo info) async {
    await _service.dismissVersion(info.manifest.build);
    state = state.copyWith(phase: AppUpdateCheckPhase.upToDate, clearInfo: true);
  }

  Future<void> autoCheckIfDue() async {
    if (!await _service.shouldAutoCheck()) return;
    await check(respectDismiss: true, markAuto: true);
  }
}
