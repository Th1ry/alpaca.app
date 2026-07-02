import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../providers/alpaca_connection_provider.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/watchlist_provider.dart';
import '../../services/api_service.dart';
import '../../services/ws_service.dart';
import '../../shared/widgets/symbol_search_field.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/okx_ui.dart';
import '../../shared/widgets/floating_capsule_nav.dart';
import 'news_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onTrade});

  final void Function(String symbol) onTrade;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, Quote> _quotes = {};
  final Map<String, List<Bar>> _sparks = {};
  bool _loading = true;
  bool _editingWatchlist = false;
  String? _revealedDeleteSym;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final watchlist = ref.read(watchlistProvider);
    if (watchlist.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final api = ref.read(apiServiceProvider);
    if (!api.isConfigured) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = S.apiNotConfigured;
        });
      }
      return;
    }
    try {
      final quotes = await api.getQuotes(watchlist);
      final barResults = await Future.wait(
        watchlist.map((sym) => api.getBars(sym, '1D').catchError((_) => <Bar>[])),
      );
      final sparks = <String, List<Bar>>{
        for (var i = 0; i < watchlist.length; i++) watchlist[i]: barResults[i],
      };
      ref.read(wsServiceProvider).subscribe(watchlist);
      if (mounted) {
        setState(() {
          _quotes
            ..clear()
            ..addAll(quotes);
          _sparks
            ..clear()
            ..addAll(sparks);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(watchlistProvider, (prev, next) {
      if (prev != null && prev != next) _load();
    });
    ref.listen(alpacaCredentialsProvider, (prev, next) {
      if (prev?.isConfigured != next.isConfigured ||
          (next.isConfigured &&
              (prev?.apiKey != next.apiKey || prev?.apiSecret != next.apiSecret))) {
        _load();
      }
    });

    ref.listen(alpacaConnectionProvider, (prev, next) {
      if (next.phase == AlpacaConnPhase.ok) _load();
    });

    final account = ref.watch(accountProvider).valueOrNull;
    final watchlist = ref.watch(watchlistProvider);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final pct = NumberFormat('+#0.00;-#0.00');

    if (_loading && _quotes.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _quotes.isEmpty) {
      return ApiErrorView(onRetry: _load, detail: S.loadFailedHint);
    }

    return Stack(
      children: [
        const Positioned.fill(child: GlassAmbientLayer()),
        RefreshIndicator(
      onRefresh: () async {
        refreshPortfolio(ref);
        ref.invalidate(newsProvider);
        await _load();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, FloatingCapsuleNav.overlayInset(context)),
        children: [
          SymbolSearchField(
            onSelected: (sym) => widget.onTrade(sym),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (account != null) ...[
                  OkxAssetHero(
                    label: S.totalAssets,
                    value: money.format(account.equity),
                    sub:
                        '${money.format(account.dailyPnl)} (${pct.format(account.dailyPnlPct)}%) ${S.today}',
                    subColor: pnlColor(account.dailyPnl),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OkxMiniStat(label: S.buyingPower, value: money.format(account.buyingPower)),
                      const SizedBox(width: 10),
                      OkxMiniStat(label: S.cash, value: money.format(account.cash)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                OkxSectionHeader(
                  title: S.watchlist,
                  trailing: TextButton(
                    onPressed: () => setState(() {
                      _editingWatchlist = !_editingWatchlist;
                      _revealedDeleteSym = null;
                    }),
                    child: Text(_editingWatchlist ? S.done : S.editWatchlist),
                  ),
                ),
                const SizedBox(height: 4),
                if (watchlist.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Text(S.watchlistEmpty, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  )
                else
                  ...watchlist.map((sym) {
                    final live = ref.watch(quoteStreamProvider(sym));
                    final q = live.valueOrNull ?? _quotes[sym];
                    final revealDelete = _editingWatchlist && _revealedDeleteSym == sym;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: revealDelete ? 44 : 0,
                            height: 44,
                            child: revealDelete
                                ? Material(
                                    color: AppColors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        ref.read(watchlistProvider.notifier).remove(sym);
                                        setState(() => _revealedDeleteSym = null);
                                      },
                                      child: Icon(Icons.remove, color: AppColors.red, size: 22),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (revealDelete) const SizedBox(width: 6),
                          Expanded(
                            child: q == null
                                ? Card(
                                    child: ListTile(
                                      dense: true,
                                      title: Text(sym),
                                      trailing: Text(
                                        '—',
                                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                                      ),
                                      onTap: _editingWatchlist
                                          ? () => setState(() {
                                                _revealedDeleteSym =
                                                    _revealedDeleteSym == sym ? null : sym;
                                              })
                                          : () => widget.onTrade(sym),
                                    ),
                                  )
                                : WatchlistTile(
                                    quote: q,
                                    sparkline: _sparks[sym] ?? [],
                                    onTap: _editingWatchlist
                                        ? () => setState(() {
                                              _revealedDeleteSym =
                                                  _revealedDeleteSym == sym ? null : sym;
                                            })
                                        : () => widget.onTrade(sym),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                NewsSection(onSymbolTap: widget.onTrade),
              ],
            ),
          ),
        ],
      ),
        ),
      ],
    );
  }
}
