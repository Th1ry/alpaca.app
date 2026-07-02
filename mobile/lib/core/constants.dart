import 'alpaca_config.dart';

class AppConstants {
  static const defaultWatchlist = ['SPY', 'QQQ', 'TSLA', 'NVDA', 'AAPL'];
  static const defaultSymbol = 'QQQ';
  static AlpacaCredentials get defaultAlpaca => AlpacaCredentials.defaults();
}
