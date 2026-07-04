import 'alpaca_config.dart';

class AppConstants {
  static const defaultWatchlist = <String>[];
  static const defaultSymbol = 'SPY';
  static AlpacaCredentials get defaultAlpaca => AlpacaCredentials.defaults();
}
