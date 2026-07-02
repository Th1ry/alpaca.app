import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/symbol_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/alpaca_connection_provider.dart';
import '../../providers/portfolio_providers.dart';
import '../../services/api_service.dart';
import '../../services/ws_service.dart';
import '../../shared/widgets/symbol_search_field.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/okx_ui.dart';
import 'bid_ask_panel.dart';
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
  });

  final String symbol;
  final String? selectedOcc;
  final ValueChanged<String>? onSymbolChange;

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen>
    with SingleTickerProviderStateMixin {
  late String _symbol;
  late TabController _tabCtrl;
  Quote? _quote;
  List<Bar> _bars = [];
  OptionsChain? _chain;
  String _timeframe = '5m';
  String _side = 'buy';
  String _orderType = 'market';
  final _qtyCtrl = TextEditingController(text: '1');
  final _limitCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  String? _selectedOcc;
  String _ratioSymbolKey = '';
  int _tabIndex = 0;

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
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging && _tabCtrl.index != _tabIndex) {
        setState(() => _tabIndex = _tabCtrl.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshPortfolio(ref);
      ref.read(wsServiceProvider).subscribe([_symbol]);
      ref.read(wsServiceProvider).subscribePortfolio();
      if (widget.selectedOcc != null) {
        _openPositionBySymbol(widget.selectedOcc!);
      }
    });
    if (widget.selectedOcc == null) {
      _load();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _qtyCtrl.dispose();
    _limitCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TradeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol && widget.selectedOcc == null) {
      _symbol = widget.symbol;
      _selectedOcc = null;
      _syncRatioSymbolReset();
      _searchCtrl.text = _symbol;
      ref.read(wsServiceProvider).subscribe([_symbol]);
      _load();
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
        ref.read(wsServiceProvider).subscribe([und]);
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
    ref.read(wsServiceProvider).subscribe([symbol]);
    _goToChartTab();
    await _load();
  }

  void _subscribeActiveQuote() {
    ref.read(wsServiceProvider).subscribe([_activeSymbol]);
  }

  Future<void> _loadChartBars([String? symbol, String? tf]) async {
    final sym = (symbol ?? _activeSymbol).toUpperCase();
    final timeframe = tf ?? _timeframe;
    try {
      final bars = await ref.read(apiServiceProvider).getBars(sym, timeframe);
      if (mounted) setState(() => _bars = bars);
    } catch (_) {}
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
        api.getQuote(occ),
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      Quote? quote;
      List<Bar> bars = [];
      Object? lastErr;
      try {
        quote = await api.getQuote(_activeSymbol);
      } catch (e) {
        lastErr = e;
      }
      try {
        bars = await api.getBars(_activeSymbol, _timeframe);
      } catch (e) {
        lastErr ??= e;
      }
      OptionsChain? chain;
      try {
        chain = await api.getOptionsChain(_symbol);
      } catch (_) {}
      if (quote == null && bars.isEmpty) {
        throw lastErr ?? Exception(S.loadFailed);
      }
      if (!mounted) return;
      setState(() {
        if (quote != null) _quote = quote;
        _bars = bars;
        if (chain != null) _chain = chain;
        _loading = false;
        _error = null;
      });
      _subscribeActiveQuote();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _goToChartTab() {
    setState(() => _tabIndex = 0);
    _tabCtrl.animateTo(0);
  }

  Future<void> _switchToStockChart() async {
    if (_selectedOcc == null) return;
    setState(() {
      _selectedOcc = null;
      _bars = [];
    });
    _syncRatioSymbolReset();
    _subscribeActiveQuote();
    await _loadChartBars(_symbol, _timeframe);
    try {
      final quote = await ref.read(apiServiceProvider).getQuote(_symbol);
      if (mounted) setState(() => _quote = quote);
    } catch (_) {}
  }

  String _formatOrderPrice(double price) =>
      price >= 1 ? price.toStringAsFixed(2) : price.toStringAsFixed(4);

  void _syncMarketOrderPrice(Quote? q) {
    if (_orderType != 'market' || q == null || q.price <= 0) return;
    final next = _formatOrderPrice(q.price);
    if (_limitCtrl.text != next) _limitCtrl.text = next;
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) return;
    final sym = _selectedOcc ?? _symbol;
    final limit = double.tryParse(_limitCtrl.text);
    try {
      await ref.read(apiServiceProvider).submitOrder(
            symbol: sym,
            qty: qty,
            side: _side,
            type: _orderType,
            limitPrice: _orderType == 'limit' ? limit : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.orderSubmitted)),
        );
        refreshPortfolio(ref);
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(alpacaCredentialsProvider, (prev, next) {
      if (next.isConfigured &&
          (prev?.apiKey != next.apiKey ||
              prev?.apiSecret != next.apiSecret ||
              prev?.apiUrl != next.apiUrl)) {
        _load();
      }
    });
    ref.listen(alpacaConnectionProvider, (prev, next) {
      if (next.phase == AlpacaConnPhase.ok) _load();
    });

    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final pct = NumberFormat('+#0.00;-#0.00');
    final liveQuote = ref.watch(quoteStreamProvider(_activeSymbol));
    final displayQuote = liveQuote.valueOrNull ?? _quote;
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
            setState(() {
              _symbol = sym;
              _selectedOcc = null;
            });
            _syncRatioSymbolReset();
            widget.onSymbolChange?.call(_symbol);
            _subscribeActiveQuote();
            _load();
          },
        ),
        if (displayQuote != null)
          TradeQuoteHeader(
            symbol: _activeSymbol,
            quote: displayQuote,
            money: (v) => money.format(v),
            pct: (v) => pct.format(v),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: OkxCapsuleSwitch(
            leftLabel: S.tabChart,
            rightLabel: S.tabOptionsChain,
            showRight: _tabIndex == 1,
            leftPillColor: AppColors.accent,
            rightPillColor: AppColors.accentSoft,
            onChanged: (chain) {
              final idx = chain ? 1 : 0;
              setState(() => _tabIndex = idx);
              _tabCtrl.animateTo(idx);
            },
          ),
        ),
        Expanded(
          flex: 3,
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _error != null
                  ? ApiErrorView(onRetry: _load, detail: S.loadFailedHint)
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _ChartOrderPage(
                          bars: _bars,
                          timeframe: _timeframe,
                          quote: displayQuote,
                          activeSymbol: _activeSymbol,
                          underlying: _symbol,
                          selectedOcc: _selectedOcc,
                          onSwitchToStock: _switchToStockChart,
                          onTimeframe: (tf) {
                            setState(() => _timeframe = tf);
                            _loadChartBars(_activeSymbol, tf);
                          },
                          side: _side,
                          orderType: _orderType,
                          qtyCtrl: _qtyCtrl,
                          limitCtrl: _limitCtrl,
                          onSide: (s) => setState(() => _side = s),
                          onType: (t) {
                            setState(() {
                              _orderType = t;
                              if (t == 'market') {
                                _syncMarketOrderPrice(displayQuote);
                              }
                            });
                          },
                          onSubmit: _submit,
                        ),
                        _OptionsPage(
                          chain: _chain,
                          onSelect: _selectOption,
                          onExpiry: (exp) async {
                            final c = await ref
                                .read(apiServiceProvider)
                                .getOptionsChain(_symbol, expiry: exp);
                            if (mounted) setState(() => _chain = c);
                          },
                        ),
                      ],
                    ),
        ),
        Expanded(flex: 2, child: TradePositionsPanel(onTapPosition: _openPosition)),
      ],
    );
  }
}

class _ChartOrderPage extends ConsumerWidget {
  static const _timeframes = ['1m', '5m', '15m', '1h', '4h', '1d'];

  const _ChartOrderPage({
    required this.bars,
    required this.timeframe,
    required this.quote,
    required this.activeSymbol,
    required this.underlying,
    required this.selectedOcc,
    required this.onSwitchToStock,
    required this.onTimeframe,
    required this.side,
    required this.orderType,
    required this.qtyCtrl,
    required this.limitCtrl,
    required this.onSide,
    required this.onType,
    required this.onSubmit,
  });

  final List<Bar> bars;
  final String timeframe;
  final Quote? quote;
  final String activeSymbol;
  final String underlying;
  final String? selectedOcc;
  final VoidCallback onSwitchToStock;
  final ValueChanged<String> onTimeframe;
  final String side;
  final String orderType;
  final TextEditingController qtyCtrl;
  final TextEditingController limitCtrl;
  final ValueChanged<String> onSide;
  final ValueChanged<String> onType;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider).valueOrNull;
    final positions = ref.watch(positionsProvider).valueOrNull ?? [];
    final isMarket = orderType == 'market';
    final orderPrice = isMarket
        ? (quote?.price ?? 0)
        : (double.tryParse(limitCtrl.text) ?? quote?.price ?? 0);
    final isOption = isOptionSymbol(activeSymbol);
    final isBuy = side.toLowerCase() == 'buy';
    final maxQty = (isBuy
            ? computeMaxBuyQty(account: account, orderPrice: orderPrice, activeSymbol: activeSymbol)
            : computeMaxSellQty(
                positions: positions, underlying: underlying, selectedOcc: selectedOcc)) ??
        0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OkxCapsuleSwitch(
                    leftLabel: S.chartStock,
                    rightLabel: S.chartOption,
                    showRight: selectedOcc != null,
                    rightEnabled: selectedOcc != null,
                    leftPillColor: AppColors.green.withValues(alpha: 0.88),
                    rightPillColor: AppColors.accentSoft,
                    onChanged: (option) {
                      if (!option) onSwitchToStock();
                    },
                    height: 36,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OkxSegmentRow(
                    options: [for (final tf in _timeframes) (tf, tf)],
                    selected: timeframe,
                    onSelect: onTimeframe,
                    fontSize: 10,
                  ),
                ),
                Expanded(
                  child: CandleChart(
                    key: ValueKey('$activeSymbol-$timeframe'),
                    bars: bars,
                    timeframe: timeframe,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(S.orderSection, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                            decoration: InputDecoration(labelText: S.qty),
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
                            onPressed: onSubmit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                              backgroundColor: isBuy ? AppColors.green : AppColors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OkxRadius.pill),
                              ),
                            ),
                            child: Text(isBuy ? S.buy : S.sell),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
