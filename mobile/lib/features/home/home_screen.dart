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
  const HomeScreen({
    super.key,
    required this.onTrade,
    this.isActive = true,
  });

  final void Function(String symbol) onTrade;
  final bool isActive;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, Quote> _quotes = {};
  final Map<String, List<Bar>> _sparks = {};
  bool _loading = false;
  bool _editingWatchlist = false;
  bool _newsEnabled = false;
  String? _revealedDeleteSym;
  String? _error;
  String? _loadedSymbolsKey;
  int _sparkGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) _loadPriority();
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _loadPriority();
    } else if (oldWidget.isActive && !widget.isActive) {
      ref.read(wsServiceProvider).setBackgroundSymbols(const []);
    }
  }

  List<String> _watchlistSymbols() => List<String>.from(ref.read(watchlistProvider));

  Future<void> _loadPriority({bool force = false}) async {
    if (!widget.isActive) return;
    final symbols = _watchlistSymbols();
    final key = symbols.join(',');
    if (!force && key == _loadedSymbolsKey && _quotes.isNotEmpty) {
      ref.read(wsServiceProvider).setBackgroundSymbols(symbols);
      if (mounted && !_newsEnabled) setState(() => _newsEnabled = true);
      return;
    }
    if (symbols.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _newsEnabled = true;
        });
      }
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quotes = await api.getQuotes(symbols);
      ref.read(wsServiceProvider).setBackgroundSymbols(symbols);
      if (mounted) {
        setState(() {
          _quotes
            ..clear()
            ..addAll(quotes);
          _loading = false;
          _newsEnabled = true;
          _loadedSymbolsKey = key;
        });
      }
      _loadSparksLazy(symbols);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _newsEnabled = true;
        });
      }
    }
  }

  Future<void> _loadSparksLazy(List<String> symbols) async {
    final gen = ++_sparkGen;
    final api = ref.read(apiServiceProvider);
    for (final sym in symbols) {
      if (!mounted || gen != _sparkGen) return;
      try {
        final bars = await api.getSparklineBars(sym);
        if (!mounted || gen != _sparkGen) return;
        setState(() => _sparks[sym] = bars);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(watchlistProvider, (prev, next) {
      if (widget.isActive && prev != null && prev != next) _loadPriority(force: true);
    });
    ref.listen(alpacaCredentialsProvider, (prev, next) {
      if (!widget.isActive) return;
      if (prev?.isConfigured != next.isConfigured ||
          (next.isConfigured &&
              (prev?.apiKey != next.apiKey || prev?.apiSecret != next.apiSecret))) {
        _loadPriority();
      }
    });

    ref.listen(alpacaConnectionProvider, (prev, next) {
      if (widget.isActive && next.phase == AlpacaConnPhase.ok) _loadPriority();
    });

    final account = ref.watch(accountProvider).valueOrNull;
    final watchlist = ref.watch(watchlistProvider);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final pct = NumberFormat('+#0.00;-#0.00');

    if (_loading && _quotes.isEmpty && watchlist.isNotEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _quotes.isEmpty && watchlist.isNotEmpty) {
      return ApiErrorView(onRetry: _loadPriority, detail: S.loadFailedHint);
    }

    return Stack(
      children: [
        const Positioned.fill(child: GlassAmbientLayer()),
        RefreshIndicator(
      onRefresh: () async {
        refreshPortfolio(ref);
        ref.invalidate(newsProvider);
        await _loadPriority(force: true);
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
                      OkxMiniStat(label: S.marginBuyingPower, value: money.format(account.marginBuyingPower)),
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
                    final q = widget.isActive
                        ? (ref.watch(quoteStreamProvider(sym)).valueOrNull ?? _quotes[sym])
                        : _quotes[sym];
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
                if (widget.isActive && _newsEnabled) const NewsSection(),
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
