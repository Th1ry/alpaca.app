import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/symbol_utils.dart';
import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/alpaca_connection_provider.dart';
import '../../providers/portfolio_providers.dart';
import '../../services/alpaca_client.dart';
import '../../services/api_service.dart';
import '../../services/order_feedback.dart';
import '../../services/ws_service.dart';
import '../../shared/widgets/floating_capsule_nav.dart';
import '../../shared/widgets/symbol_search_field.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/okx_ui.dart';
import 'bid_ask_panel.dart';
import 'depth_book_panel.dart';
import 'order_capacity_panel.dart';
import 'order_qty_utils.dart';
import 'qty_ratio_slider.dart';
import 'trade_positions_panel.dart';

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({
    super.key,
    required this.symbol,
    this.selectedOcc,
    this.onSymbolChange,
    this.isActive = false,
  });

  final String symbol;
  final String? selectedOcc;
  final ValueChanged<String>? onSymbolChange;
  final bool isActive;

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  late String _symbol;
  Quote? _quote;
  List<Bar> _bars = [];
  OptionsChain? _chain;
  String _timeframe = '5m';
  String _side = 'buy';
  String _orderType = 'market';
  final _qtyCtrl = TextEditingController(text: '1');
  final _limitCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  String? _selectedOcc;
  String _ratioSymbolKey = '';
  int _tabIndex = 0;
  bool _chartExpanded = true;
  int _loadGen = 0;

  static const _chartExpandedHeight = 220.0;

  String get _activeSymbol => (_selectedOcc ?? _symbol).toUpperCase();

  void _syncRatioSymbolReset() {
    final key = _activeSymbol;
    if (_ratioSymbolKey == key) return;
    _ratioSymbolKey = key;
    _qtyCtrl.text = '1';
  }

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol;
    _ratioSymbolKey = _activeSymbol;
    _searchCtrl.text = widget.symbol;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedOcc != null) {
        _openPositionBySymbol(widget.selectedOcc!);
      } else if (widget.isActive && widget.symbol.isNotEmpty) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _limitCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TradeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      if (widget.selectedOcc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openPositionBySymbol(widget.selectedOcc!);
        });
      } else if (widget.symbol.isNotEmpty) {
        if (_quote == null && !_loading) {
          _load();
        } else {
          _subscribeActiveQuote();
        }
      }
    }
    if (widget.selectedOcc != oldWidget.selectedOcc && widget.selectedOcc != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPositionBySymbol(widget.selectedOcc!);
      });
      return;
    }
    if (oldWidget.symbol != widget.symbol && widget.selectedOcc == null) {
      _symbol = widget.symbol;
      _selectedOcc = null;
      _syncRatioSymbolReset();
      _searchCtrl.text = _symbol;
      if (widget.isActive && _symbol.isNotEmpty) {
        _load();
      } else if (_symbol.isEmpty) {
        setState(() {
          _quote = null;
          _bars = [];
          _chain = null;
          _loading = false;
          _error = null;
        });
        ref.read(wsServiceProvider).setFocusSymbol(null);
      }
    }
    if (oldWidget.isActive && !widget.isActive) {
      ref.read(wsServiceProvider).setFocusSymbol(null);
    }
  }

  String _sideForPosition(Position p) =>
      p.side.toLowerCase() == 'short' ? 'buy' : 'sell';

  Future<void> _openPosition(Position p) => _openPositionBySymbol(p.symbol, side: _sideForPosition(p));

  Future<void> _openPositionBySymbol(String sym, {String? side}) async {
    final symbol = sym.toUpperCase();
    if (isOptionSymbol(symbol)) {
      final und = optionUnderlying(symbol) ?? _symbol;
      if (_symbol != und) {
        setState(() => _symbol = und);
        widget.onSymbolChange?.call(und);
        _searchCtrl.text = und;
      }
      final positions = ref.read(positionsProvider).valueOrNull ?? [];
      Position? pos;
      for (final p in positions) {
        if (p.symbol.toUpperCase() == symbol) {
          pos = p;
          break;
        }
      }
      final orderSide = side ?? (pos != null ? _sideForPosition(pos) : 'sell');
      await _selectOption(symbol, orderSide);
      return;
    }
    setState(() {
      _symbol = symbol;
      _selectedOcc = null;
      if (side != null) _side = side;
    });
    _syncRatioSymbolReset();
    widget.onSymbolChange?.call(symbol);
    _searchCtrl.text = symbol;
    _goToChartTab();
    await _load();
  }

  void _subscribeActiveQuote() {
    if (!widget.isActive || _symbol.isEmpty) return;
    ref.read(wsServiceProvider).setFocusSymbol(_activeSymbol);
  }

  Future<void> _loadChartBars([String? symbol, String? tf]) async {
    final sym = (symbol ?? _activeSymbol).toUpperCase();
    final timeframe = tf ?? _timeframe;
    final gen = _loadGen;
    try {
      final bars = await ref.read(apiServiceProvider).getBars(sym, timeframe);
      if (!mounted || gen != _loadGen) return;
      setState(() => _bars = bars);
    } catch (_) {}
  }

  void _loadOptionsChainInBackground({required int gen}) {
    ref.read(apiServiceProvider).getOptionsChain(_symbol).then((chain) {
      if (!mounted || gen != _loadGen) return;
      setState(() => _chain = chain);
    }).catchError((_) {});
  }

  Future<void> _selectOption(String occ, String side) async {
    setState(() {
      _selectedOcc = occ;
      _side = side;
      _orderType = 'limit';
      _bars = [];
    });
    _syncRatioSymbolReset();
    _subscribeActiveQuote();
    _goToChartTab();
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getMarketSnapshot(occ).then((s) => s.quote),
        api.getBars(occ, _timeframe),
      ]);
      if (!mounted) return;
      final quote = results[0] as Quote;
      final bars = results[1] as List<Bar>;
      setState(() {
        _quote = quote;
        _bars = bars;
        _limitCtrl.text = _formatOrderPrice(quote.price);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('期权图表加载失败: $e')),
        );
      }
    }
  }

  Future<void> _load() async {
    if (!widget.isActive || _symbol.isEmpty) return;
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(apiServiceProvider);
    if (!api.isConfigured) {
      if (mounted && gen == _loadGen) {
        setState(() {
          _loading = false;
          _error = S.apiNotConfigured;
        });
      }
      return;
    }

    try {
      Quote? quote;
      List<Bar> bars = [];
      Object? lastErr;
      final sym = _activeSymbol;

      await Future.wait([
        api.getMarketSnapshot(sym).then((snap) {
          quote = snap.quote;
        }).catchError((Object e) async {
          lastErr = e;
          try {
            quote = await api.getQuote(sym);
          } catch (e2) {
            lastErr ??= e2;
          }
        }),
        api.getBars(sym, _timeframe).then((b) {
          bars = b;
        }).catchError((Object e) {
          lastErr ??= e;
        }),
      ]);

      if (!mounted || gen != _loadGen) return;

      final hasQuote = quote != null && quote!.price > 0;
      if (!hasQuote && bars.isEmpty) {
        throw lastErr ?? Exception(S.loadFailed);
      }

      setState(() {
        if (hasQuote) _quote = quote;
        _bars = bars;
        _loading = false;
        _error = null;
      });
      _subscribeActiveQuote();
      _loadOptionsChainInBackground(gen: gen);
      if (bars.isEmpty && hasQuote) {
        _loadChartBars(sym, _timeframe);
      }
    } catch (e) {
      if (mounted && gen == _loadGen) {
        setState(() {
          _loading = false;
          _error = e is AlpacaApiException ? e.message : e.toString();
        });
      }
    }
  }

  void _goToChartTab() {
    setState(() => _tabIndex = 0);
  }

  void _goToOptionsTab() {
    setState(() => _tabIndex = 1);
  }

  String _formatOrderPrice(double price) =>
      price >= 1 ? price.toStringAsFixed(2) : price.toStringAsFixed(4);

  void _syncMarketOrderPrice(Quote? q) {
    if (_orderType != 'market' || q == null || q.price <= 0) return;
    final next = _formatOrderPrice(q.price);
    if (_limitCtrl.text != next) _limitCtrl.text = next;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) return;
    final sym = _selectedOcc ?? _symbol;
    final limit = double.tryParse(_limitCtrl.text);
    setState(() => _submitting = true);
    try {
      final order = await ref.read(apiServiceProvider).submitOrder(
            symbol: sym,
            qty: qty,
            side: _side,
            type: _orderType,
            limitPrice: _orderType == 'limit' ? limit : null,
          );
      if (!mounted) return;
      onOrderCompleted(ref, order);
      showOrderResultSnackBar(context, order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(alpacaCredentialsProvider, (prev, next) {
      if (!widget.isActive) return;
      if (next.isConfigured &&
          (prev?.apiKey != next.apiKey ||
              prev?.apiSecret != next.apiSecret ||
              prev?.apiUrl != next.apiUrl)) {
        _load();
      }
    });
    ref.listen(alpacaConnectionProvider, (prev, next) {
      if (!widget.isActive || _symbol.isEmpty) return;
      if (prev?.phase != AlpacaConnPhase.ok &&
          next.phase == AlpacaConnPhase.ok &&
          (_error != null || _quote == null)) {
        _load();
      }
    });

    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final pct = NumberFormat('+#0.00;-#0.00');
    final liveSnap = widget.isActive && _symbol.isNotEmpty
        ? ref.watch(marketSnapshotStreamProvider(_activeSymbol))
        : const AsyncValue<MarketSnapshot?>.data(null);
    final displayQuote = liveSnap.valueOrNull?.quote ?? _quote;
    final displayBook = liveSnap.valueOrNull?.orderBook;
    if (_orderType == 'market' && displayQuote != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncMarketOrderPrice(displayQuote);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SymbolSearchField(
          controller: _searchCtrl,
          onSelected: (sym) {
            final next = sym.toUpperCase();
            if (next == _symbol.toUpperCase()) return;
            widget.onSymbolChange?.call(next);
          },
        ),
        if (displayQuote != null)
          TradeQuoteHeader(
            symbol: _activeSymbol,
            quote: displayQuote,
            orderBook: displayBook,
            money: (v) => money.format(v),
            pct: (v) => pct.format(v),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Align(
            alignment: _tabIndex == 0 ? Alignment.centerRight : Alignment.centerLeft,
            child: _TradeActionKey(
              label: _tabIndex == 0 ? S.tabOptionsChain : S.backToChart,
              icon: _tabIndex == 0 ? Icons.view_list_rounded : Icons.arrow_back_rounded,
              onTap: _tabIndex == 0 ? _goToOptionsTab : _goToChartTab,
            ),
          ),
        ),
        Expanded(
          child: _symbol.isEmpty
              ? Center(
                  child: Text(
                    S.searchSymbolOrName,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                )
              : _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                  ? ApiErrorView(
                      onRetry: _load,
                      detail: _error ?? S.loadFailedHint,
                    )
                  : _tabIndex == 0
                      ? _buildChartTab(
                          displayQuote: displayQuote,
                          account: ref.watch(accountProvider).valueOrNull,
                          positions: ref.watch(positionsProvider).valueOrNull ?? [],
                        )
                      : _OptionsPage(
                          chain: _chain,
                          onSelect: _selectOption,
                          onExpiry: (exp) async {
                            final c = await ref
                                .read(apiServiceProvider)
                                .getOptionsChain(_symbol, expiry: exp);
                            if (mounted) setState(() => _chain = c);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildChartTab({
    required Quote? displayQuote,
    required AccountSummary? account,
    required List<Position> positions,
  }) {
    final isMarket = _orderType == 'market';
    final orderPrice = isMarket
        ? (displayQuote?.price ?? 0)
        : (double.tryParse(_limitCtrl.text) ?? displayQuote?.price ?? 0);
    final isOption = isOptionSymbol(_activeSymbol);
    final isBuy = _side.toLowerCase() == 'buy';
    final maxQty = (isBuy
            ? computeMaxBuyQty(
                account: account, orderPrice: orderPrice, activeSymbol: _activeSymbol)
            : computeMaxSellQty(
                positions: positions, underlying: _symbol, selectedOcc: _selectedOcc)) ??
        0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + FloatingCapsuleNav.overlayInset(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(OkxRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(OkxRadius.md),
              onTap: () => setState(() => _chartExpanded = !_chartExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      S.tabChart,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (_selectedOcc != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedOcc!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: AppColors.accentSoft),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Icon(
                      _chartExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 22,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_chartExpanded) ...[
            const SizedBox(height: 8),
            OkxSegmentRow(
              options: [for (final tf in _ChartTabBody.timeframes) (tf, tf)],
              selected: _timeframe,
              onSelect: (tf) {
                setState(() => _timeframe = tf);
                _loadChartBars(_activeSymbol, tf);
              },
              fontSize: 10,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _chartExpandedHeight,
              child: CandleChart(
                key: ValueKey('$_activeSymbol-$_timeframe'),
                bars: _bars,
                timeframe: _timeframe,
              ),
            ),
          ],
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: DepthBookPanel(symbol: _activeSymbol),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _OrderFormColumn(
                  selectedOcc: _selectedOcc,
                  side: _side,
                  orderType: _orderType,
                  qtyCtrl: _qtyCtrl,
                  limitCtrl: _limitCtrl,
                  activeSymbol: _activeSymbol,
                  underlying: _symbol,
                  isOption: isOption,
                  isBuy: isBuy,
                  maxQty: maxQty,
                  orderPrice: orderPrice,
                  account: account,
                  positions: positions,
                  onSide: (s) => setState(() => _side = s),
                  onType: (t) {
                    setState(() {
                      _orderType = t;
                      if (t == 'market') _syncMarketOrderPrice(displayQuote);
                    });
                  },
                  onSubmit: _submit,
                  submitting: _submitting,
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 16),
          TradePositionsPanel(onTapPosition: _openPosition, embedded: true),
        ],
      ),
    );
  }
}

/// Glass-style tap key for trade sub-navigation (no swipe).
class _TradeActionKey extends StatelessWidget {
  const _TradeActionKey({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: OkxRadius.pill,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.text),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _OrderFormColumn extends StatelessWidget {
  const _OrderFormColumn({
    required this.selectedOcc,
    required this.side,
    required this.orderType,
    required this.qtyCtrl,
    required this.limitCtrl,
    required this.activeSymbol,
    required this.underlying,
    required this.isOption,
    required this.isBuy,
    required this.maxQty,
    required this.orderPrice,
    required this.account,
    required this.positions,
    required this.onSide,
    required this.onType,
    required this.onSubmit,
    this.submitting = false,
  });

  final String? selectedOcc;
  final String side;
  final String orderType;
  final TextEditingController qtyCtrl;
  final TextEditingController limitCtrl;
  final String activeSymbol;
  final String underlying;
  final bool isOption;
  final bool isBuy;
  final double maxQty;
  final double orderPrice;
  final AccountSummary? account;
  final List<Position> positions;
  final ValueChanged<String> onSide;
  final ValueChanged<String> onType;
  final Future<void> Function() onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final isMarket = orderType == 'market';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.orderSection, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (selectedOcc != null) ...[
          const SizedBox(height: 6),
          Text(
            '合约: $selectedOcc',
            style: TextStyle(color: AppColors.accentSoft, fontSize: 11),
          ),
        ],
        const SizedBox(height: 10),
        OkxBuySellBar(
          side: side,
          onChanged: onSide,
          buyLabel: S.buy,
          sellLabel: S.sell,
        ),
        const SizedBox(height: 10),
        OkxOrderTypeSwitch(
          value: orderType,
          onChanged: onType,
          marketLabel: S.market,
          limitLabel: S.limit,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: S.qtyUnit(isOption: isOption)),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        QtyRatioSlider(
          symbol: activeSymbol,
          maxQty: maxQty,
          isOption: isOption,
          qtyCtrl: qtyCtrl,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: limitCtrl,
          readOnly: isMarket,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: S.orderPrice,
            filled: isMarket,
            fillColor: isMarket ? AppColors.card : null,
          ),
        ),
        const SizedBox(height: 10),
        OrderCapacityPanel(
          side: side,
          account: account,
          orderPrice: orderPrice,
          activeSymbol: activeSymbol,
          underlying: underlying,
          selectedOcc: selectedOcc,
          positions: positions,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: submitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(42),
            backgroundColor: isBuy ? AppColors.green : AppColors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OkxRadius.pill),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isBuy ? S.buy : S.sell),
        ),
      ],
    );
  }
}

/// Timeframe list shared by chart tab.
class _ChartTabBody {
  static const timeframes = ['1m', '5m', '15m', '1h', '4h', '1d'];
}

class _OptionsPage extends StatefulWidget {
  const _OptionsPage({
    required this.chain,
    required this.onSelect,
    required this.onExpiry,
  });

  final OptionsChain? chain;
  final void Function(String occ, String side) onSelect;
  final ValueChanged<String> onExpiry;

  @override
  State<_OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<_OptionsPage> {
  String? _expiry;
  final _scrollCtrl = ScrollController();
  String? _scrollKey;
  static const _rowHeight = 60.0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OptionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final c = widget.chain;
    if (c == null) return;
    if (oldWidget.chain?.expiry != c.expiry) {
      _expiry = c.expiry;
    }
    _maybeScrollToSpot(c);
  }

  void _maybeScrollToSpot(OptionsChain chain) {
    if (chain.chain.isEmpty) return;
    final key = '${chain.symbol}:${chain.expiry}:${chain.spot}:${chain.chain.length}';
    if (_scrollKey == key) return;
    _scrollKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSpot(chain));
  }

  void _scrollToSpot(OptionsChain chain) {
    if (!mounted || !_scrollCtrl.hasClients || chain.chain.isEmpty) return;
    final spot = chain.spot;
    var atmIdx = 0;
    var minDiff = double.infinity;
    for (var i = 0; i < chain.chain.length; i++) {
      final diff = (chain.chain[i].strike - spot).abs();
      if (diff < minDiff) {
        minDiff = diff;
        atmIdx = i;
      }
    }
    final viewport = _scrollCtrl.position.viewportDimension;
    final target = atmIdx * _rowHeight - viewport / 2 + _rowHeight / 2;
    final max = _scrollCtrl.position.maxScrollExtent;
    _scrollCtrl.jumpTo(target.clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    final chain = widget.chain;
    if (chain == null) {
      return Center(child: Text(S.loadingOptions));
    }
    _expiry ??= chain.expiry;
    _maybeScrollToSpot(chain);
    final money = NumberFormat('0.00');
    final atmStrike = chain.chain.isEmpty
        ? chain.spot
        : chain.chain
            .reduce((a, b) =>
                (a.strike - chain.spot).abs() < (b.strike - chain.spot).abs() ? a : b)
            .strike;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DropdownButtonFormField<String>(
            value: _expiry,
            decoration: InputDecoration(labelText: S.expiry),
            items: chain.expirations
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _expiry = v;
                  _scrollKey = null;
                });
                widget.onExpiry(v);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Call',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  money.format(chain.spot),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Put',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: chain.chain.isEmpty
              ? Center(child: Text(S.noOptionsChain, style: TextStyle(color: AppColors.muted)))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemExtent: _rowHeight,
                  itemCount: chain.chain.length,
                  itemBuilder: (context, i) {
                    final row = chain.chain[i];
                    final isAtm = row.strike == atmStrike;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      color: isAtm ? AppColors.card : null,
                      shape: isAtm
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.accent, width: 1),
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: row.callOcc != null
                                    ? () => widget.onSelect(row.callOcc!, 'buy')
                                    : null,
                                child: Text(
                                  '${money.format(row.callBid ?? 0)} / ${money.format(row.callAsk ?? 0)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text(
                                money.format(row.strike),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAtm ? AppColors.accent : null,
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: row.putOcc != null
                                    ? () => widget.onSelect(row.putOcc!, 'buy')
                                    : null,
                                child: Text(
                                  '${money.format(row.putBid ?? 0)} / ${money.format(row.putAsk ?? 0)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
