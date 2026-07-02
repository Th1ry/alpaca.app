import 'package:shared_preferences/shared_preferences.dart';

class DismissedPositionsStore {
  static const _key = 'dismissed_positions';

  Future<Set<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? const []).map((s) => s.toUpperCase()).toSet();
  }

  Future<void> dismiss(String symbol) async {
    final sym = symbol.toUpperCase();
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key) ?? <String>[];
    if (!list.contains(sym)) {
      list.add(sym);
      await p.setStringList(_key, list);
    }
  }
}
