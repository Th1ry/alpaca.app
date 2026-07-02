import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/symbol_utils.dart';
import '../../models/models.dart';

final _qtyDisplayFmt = NumberFormat('#,##0.##');
final _qtyIntFmt = NumberFormat('#,##0');

double? computeMaxBuyQty({
  required AccountSummary? account,
  required double orderPrice,
  required String activeSymbol,
}) {
  if (account == null || orderPrice <= 0) return null;
  final mult = isOptionSymbol(activeSymbol) ? 100.0 : 1.0;
  final perUnit = orderPrice * mult;
  if (perUnit <= 0) return null;
  final raw = account.marginBuyingPower / perUnit;
  if (raw <= 0) return 0;
  if (isOptionSymbol(activeSymbol)) return raw.floorToDouble();
  return (raw * 100).floorToDouble() / 100;
}

double? computeMaxSellQty({
  required List<Position> positions,
  required String underlying,
  String? selectedOcc,
}) {
  final pos = findPositionForTrade(positions, underlying, selectedOcc: selectedOcc);
  if (pos == null) return 0;
  if (pos.side.toLowerCase() == 'short') return 0;
  return pos.qty;
}

/// Apply funds/position ratio; options qty is floored.
double qtyFromRatio(double ratio, double maxQty, {required bool isOption}) {
  if (maxQty <= 0) return 0;
  final raw = maxQty * ratio.clamp(0.0, 1.0);
  if (isOption) return raw.floorToDouble();
  return (raw * 100).floorToDouble() / 100;
}

String formatOrderQty(double qty, {required bool isOption}) {
  if (qty <= 0) return '0';
  if (isOption) return qty.floor().toString();
  if (qty >= 1) return qty.toStringAsFixed(2);
  return qty.toStringAsFixed(4);
}

String formatQtyWithUnit(num qty, {required bool isOption}) {
  if (qty <= 0) return '0${S.qtyUnit(isOption: isOption)}';
  final numStr =
      isOption ? _qtyIntFmt.format(qty.floor()) : _qtyDisplayFmt.format(qty);
  return '$numStr${S.qtyUnit(isOption: isOption)}';
}

String formatQtyWithUnitForSymbol(num qty, String symbol) =>
    formatQtyWithUnit(qty, isOption: isOptionSymbol(symbol));
