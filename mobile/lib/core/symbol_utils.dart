import '../models/models.dart';

final _occRe = RegExp(r'^([A-Z]{1,6})(\d{6})([CP])(\d{8})$');

String? optionUnderlying(String symbol) {
  final m = _occRe.firstMatch(symbol.toUpperCase());
  return m?.group(1);
}

bool isOptionSymbol(String symbol) => _occRe.hasMatch(symbol.toUpperCase());

DateTime? optionExpiryUtc(String symbol) {
  final m = _occRe.firstMatch(symbol.toUpperCase());
  if (m == null) return null;
  final yymmdd = m.group(2)!;
  final y = int.parse('20${yymmdd.substring(0, 2)}');
  final mo = int.parse(yymmdd.substring(2, 4));
  final d = int.parse(yymmdd.substring(4, 6));
  return DateTime.utc(y, mo, d);
}

/// True after 20:00 UTC on the contract expiration date.
bool isOptionExpired(String symbol, [DateTime? nowUtc]) {
  final exp = optionExpiryUtc(symbol);
  if (exp == null) return false;
  nowUtc ??= DateTime.now().toUtc();
  final expClose = DateTime.utc(exp.year, exp.month, exp.day, 20);
  return !nowUtc.isBefore(expClose);
}

String formatOptionPositionLabel(String symbol) {
  final m = _occRe.firstMatch(symbol.toUpperCase());
  if (m == null) return symbol;
  final root = m.group(1)!;
  final yymmdd = m.group(2)!;
  final cp = m.group(3)!;
  final strikeRaw = m.group(4)!;
  final strike = int.parse(strikeRaw) / 1000.0;
  final y = int.parse('20${yymmdd.substring(0, 2)}');
  final mo = yymmdd.substring(2, 4);
  final d = yymmdd.substring(4, 6);
  final type = cp == 'C' ? 'C' : 'P';
  final strikeText = strike == strike.roundToDouble()
      ? strike.toStringAsFixed(0)
      : strike.toStringAsFixed(2);
  return '$root $strikeText$type · $y-$mo-$d';
}

/// Watchlist + open positions (including option contracts and underlyings).
List<String> collectPrioritySymbols(List<String> watchlist, List<Position> positions) {
  final out = <String>{};
  for (final raw in watchlist) {
    final sym = raw.trim().toUpperCase();
    if (sym.isNotEmpty) out.add(sym);
  }
  for (final p in positions) {
    final sym = p.symbol.trim().toUpperCase();
    if (sym.isEmpty) continue;
    out.add(sym);
    if (isOptionSymbol(sym)) {
      final und = optionUnderlying(sym);
      if (und != null && und.isNotEmpty) out.add(und);
    }
  }
  return out.toList();
}

List<Position> withoutExpiredOptions(List<Position> positions) {
  return positions
      .where((p) => !isOptionSymbol(p.symbol) || !isOptionExpired(p.symbol))
      .toList();
}

bool isWorthlessOption(Position position) {
  if (!isOptionSymbol(position.symbol)) return false;
  return position.price <= 0.01 && position.price * position.qty * 100 <= 1.0;
}

/// Match position for trade view: selected OCC > equity > options on underlying.
Position? findPositionForTrade(
  List<Position> positions,
  String underlying, {
  String? selectedOcc,
}) {
  final sym = underlying.toUpperCase();
  if (selectedOcc != null) {
    final occ = selectedOcc.toUpperCase();
    for (final p in positions) {
      if (p.symbol.toUpperCase() == occ) return p;
    }
  }
  for (final p in positions) {
    if (p.symbol.toUpperCase() == sym) return p;
  }
  final related = positions.where((p) => optionUnderlying(p.symbol) == sym).toList();
  if (related.length == 1) return related.first;
  return null;
}

List<Position> optionPositionsForUnderlying(List<Position> positions, String underlying) {
  final sym = underlying.toUpperCase();
  return positions.where((p) => optionUnderlying(p.symbol) == sym).toList();
}
