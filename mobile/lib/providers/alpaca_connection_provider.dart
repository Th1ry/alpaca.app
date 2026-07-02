import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alpaca_config.dart';
import '../core/strings.dart';
import '../services/alpaca_client.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';
import 'app_settings_provider.dart';
import 'portfolio_providers.dart';

enum AlpacaConnPhase { idle, empty, testing, ok, fail }

class AlpacaConnectionView {
  const AlpacaConnectionView({
    this.phase = AlpacaConnPhase.idle,
    this.busy = false,
    this.detail,
    this.error,
  });

  final AlpacaConnPhase phase;
  final bool busy;
  final String? detail;
  final String? error;

  AlpacaConnectionView copyWith({
    AlpacaConnPhase? phase,
    bool? busy,
    String? detail,
    String? error,
    bool clearDetail = false,
    bool clearError = false,
  }) {
    return AlpacaConnectionView(
      phase: phase ?? this.phase,
      busy: busy ?? this.busy,
      detail: clearDetail ? null : (detail ?? this.detail),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final alpacaConnectionProvider =
    StateNotifierProvider<AlpacaConnectionNotifier, AlpacaConnectionView>((ref) {
  return AlpacaConnectionNotifier(ref);
});

class AlpacaConnectionNotifier extends StateNotifier<AlpacaConnectionView> {
  AlpacaConnectionNotifier(this._ref) : super(const AlpacaConnectionView()) {
    _ref.listen(alpacaCredentialsProvider, (prev, next) {
      if (_internalCredentialUpdate || prev == next) return;
      if (!next.isConfigured) {
        state = const AlpacaConnectionView(phase: AlpacaConnPhase.empty);
        return;
      }
      if (prev?.apiKey != next.apiKey ||
          prev?.apiSecret != next.apiSecret ||
          prev?.apiUrl != next.apiUrl) {
        verify(showSnack: false);
      }
    });
    Future.microtask(_bootstrap);
  }

  final Ref _ref;
  bool _internalCredentialUpdate = false;

  Future<void> _persist(AlpacaCredentials creds) async {
    _internalCredentialUpdate = true;
    try {
      await _ref.read(appSettingsProvider.notifier).saveAlpaca(creds);
    } finally {
      _internalCredentialUpdate = false;
    }
  }

  Future<void> _bootstrap() async {
    final creds = _ref.read(alpacaCredentialsProvider);
    if (creds.isConfigured) {
      await verify(creds: creds, showSnack: false);
    } else {
      state = const AlpacaConnectionView(phase: AlpacaConnPhase.empty);
    }
  }

  String _formatError(String? raw) {
    if (raw == null || raw.isEmpty) return S.apiStatusFailed;
    if (raw == 'missing_keys') return S.apiNotConfigured;
    return raw;
  }

  void _refreshAppData() {
    _ref.read(portfolioRefreshProvider.notifier).state++;
    _ref.read(wsServiceProvider).subscribePortfolio(force: true);
    _ref.invalidate(accountProvider);
    _ref.invalidate(positionsProvider);
    _ref.invalidate(ordersProvider);
  }

  /// Test credentials. When [persistOnSuccess] is true, saves to device on success.
  Future<bool> verify({
    AlpacaCredentials? creds,
    bool persistOnSuccess = false,
    bool showSnack = false,
  }) async {
    final AlpacaCredentials c = creds ?? _ref.read(alpacaCredentialsProvider);
    if (!c.isConfigured) {
      state = AlpacaConnectionView(
        phase: AlpacaConnPhase.empty,
        error: S.apiNotConfigured,
      );
      return false;
    }

    state = state.copyWith(
      busy: true,
      phase: AlpacaConnPhase.testing,
      clearDetail: true,
      clearError: true,
    );

    final result = await AlpacaClient(c).testConnection();

    if (persistOnSuccess && result.ok) {
      await _persist(c);
    }

    if (result.ok) {
      state = AlpacaConnectionView(
        phase: AlpacaConnPhase.ok,
        detail: S.apiConnectedDetail(result.paper, result.equity),
      );
      _refreshAppData();
      return true;
    }

    state = AlpacaConnectionView(
      phase: AlpacaConnPhase.fail,
      detail: persistOnSuccess ? null : S.apiSavedLocal,
      error: _formatError(result.error),
    );
    return false;
  }

  /// Always persist credentials, then verify against Alpaca.
  Future<bool> save(AlpacaCredentials creds) async {
    if (!creds.isConfigured) {
      state = AlpacaConnectionView(
        phase: AlpacaConnPhase.empty,
        error: S.apiNotConfigured,
      );
      return false;
    }

    state = state.copyWith(
      busy: true,
      phase: AlpacaConnPhase.testing,
      clearDetail: true,
      clearError: true,
    );

    await _persist(creds);
    return verify(creds: creds, showSnack: false);
  }
}
