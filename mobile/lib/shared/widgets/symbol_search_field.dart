import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/watchlist_provider.dart';
import '../../services/api_service.dart';

class SymbolSearchField extends ConsumerStatefulWidget {
  const SymbolSearchField({
    super.key,
    this.controller,
    required this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.hintText,
  });

  final TextEditingController? controller;
  final ValueChanged<String> onSelected;
  final EdgeInsets padding;
  final String? hintText;

  @override
  ConsumerState<SymbolSearchField> createState() => _SymbolSearchFieldState();
}

class _SymbolSearchFieldState extends ConsumerState<SymbolSearchField> {
  late final TextEditingController _ctrl;
  late final bool _ownsController;
  Timer? _debounce;
  List<SearchResult> _results = [];
  bool _searching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onTextChanged);
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final q = _ctrl.text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _showResults = false;
        _searching = false;
      });
      return;
    }
    setState(() {
      _showResults = true;
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    try {
      final results = await ref.read(apiServiceProvider).searchSymbols(q);
      if (!mounted || _ctrl.text.trim() != q) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(SearchResult item) {
    setState(() {
      _showResults = false;
      _results = [];
      _ctrl.text = item.symbol;
    });
    FocusScope.of(context).unfocus();
    widget.onSelected(item.symbol);
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = ref.watch(watchlistProvider);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hintText ?? S.searchSymbolOrName,
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 16, color: AppColors.muted),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() {
                          _results = [];
                          _showResults = false;
                        });
                      },
                    )
                  : null,
            ),
            onTap: () {
              if (_ctrl.text.trim().isNotEmpty) {
                setState(() => _showResults = true);
              }
            },
          ),
          if (_showResults && (_searching || _results.isNotEmpty || _ctrl.text.trim().isNotEmpty))
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(OkxRadius.md),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(S.noSearchResults, style: TextStyle(color: AppColors.muted)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, i) {
                            final item = _results[i];
                            final starred = watchlist.contains(item.symbol);
                            return InkWell(
                              onTap: () => _pick(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.symbol,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (item.name.isNotEmpty)
                                            Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        starred ? Icons.star : Icons.star_border,
                                        color: starred ? AppColors.accent : AppColors.muted2,
                                        size: 22,
                                      ),
                                      tooltip: starred ? S.removeWatchlist : S.addWatchlist,
                                      onPressed: () async {
                                        await ref.read(watchlistProvider.notifier).toggle(item.symbol);
                                        if (mounted) setState(() {});
                                        if (!starred && mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${S.addedWatchlist} ${item.symbol}')),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
        ],
      ),
    );
  }
}
