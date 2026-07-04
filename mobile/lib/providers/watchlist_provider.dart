import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _watchlistKey = 'watchlist_v1';

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, List<String>>((ref) {
  final notifier = WatchlistNotifier();
  notifier.load();
  return notifier;
});

class WatchlistNotifier extends StateNotifier<List<String>> {
  WatchlistNotifier() : super(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_watchlistKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved.map((s) => s.toUpperCase()).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_watchlistKey, state);
  }

  bool contains(String symbol) => state.contains(symbol.toUpperCase());

  Future<void> add(String symbol) async {
    final sym = symbol.toUpperCase();
    if (contains(sym)) return;
    state = [...state, sym];
    await _save();
  }

  Future<void> remove(String symbol) async {
    final sym = symbol.toUpperCase();
    state = state.where((s) => s != sym).toList();
    await _save();
  }

  Future<void> toggle(String symbol) async {
    if (contains(symbol)) {
      await remove(symbol);
    } else {
      await add(symbol);
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _save();
  }
}
