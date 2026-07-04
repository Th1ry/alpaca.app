import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alpaca_config.dart';
import '../core/strings.dart';
import '../models/models.dart';
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
    _ref.listen<AsyncValue<AccountSummary?>>(accountProvider, (prev, next) {
      next.whenData(_syncFromAccount);
    });
    Future.microtask(_bootstrap);
  }

  final Ref _ref;
  bool _internalCredentialUpdate = false;

  void _syncFromAccount(AccountSummary? account) {
    if (account == null || state.busy) return;
    if (state.phase == AlpacaConnPhase.ok) return;
    final creds = _ref.read(alpacaCredentialsProvider);
    if (!creds.isConfigured) return;
    state = AlpacaConnectionView(
      phase: AlpacaConnPhase.ok,
      detail: S.apiConnectedDetail(creds.isPaper, account.equity),
    );
  }

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

  String _formatError(String? raw, {AlpacaCredentials? creds}) {
    if (raw == null || raw.isEmpty) return S.apiStatusFailed;
    if (raw == 'missing_keys') return S.apiNotConfigured;
    if (raw == 'network_timeout' || raw == 'network_unreachable') {
      return S.apiErrorNetwork;
    }
    if (raw.startsWith('unauthorized:')) {
      final paper = raw.endsWith(':paper');
      return S.apiErrorUnauthorized(paper);
    }
    final lower = raw.toLowerCase();
    if (lower.contains('unauthorized') || lower.contains('forbidden')) {
      final paper = creds?.isPaper ?? _ref.read(alpacaCredentialsProvider).isPaper;
      return S.apiErrorUnauthorized(paper);
    }
    return raw;
  }

  String _connectedDetail(AlpacaConnectionInfo result) =>
      S.apiConnectedDetail(result.paper, result.equity);

  void _refreshAppData() {
    _ref.read(portfolioRefreshProvider.notifier).state++;
    _ref.read(wsServiceProvider).pollPortfolioNow();
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
        detail: _connectedDetail(result),
      );
      _refreshAppData();
      return true;
    }

    state = AlpacaConnectionView(
      phase: AlpacaConnPhase.fail,
      detail: persistOnSuccess ? null : S.apiSavedLocal,
      error: _formatError(result.error, creds: c),
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
