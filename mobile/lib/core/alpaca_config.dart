/// Alpaca API credentials — stored on device, used by the mobile app directly.
class AlpacaCredentials {
  const AlpacaCredentials({
    required this.apiUrl,
    required this.apiKey,
    required this.apiSecret,
    this.dataFeed = 'iex',
    this.optionFeed = 'indicative',
  });

  static const dataBase = 'https://data.alpaca.markets';
  static const paperUrl = 'https://paper-api.alpaca.markets';
  static const liveUrl = 'https://api.alpaca.markets';

  final String apiUrl;
  final String apiKey;
  final String apiSecret;
  final String dataFeed;
  final String optionFeed;

  bool get isConfigured => apiKey.isNotEmpty && apiSecret.isNotEmpty;

  bool get isPaper => apiUrl.contains('paper');

  String get tradingBase {
    var base = apiUrl.replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/v2')) {
      base = base.substring(0, base.length - 3);
    }
    return base;
  }

  factory AlpacaCredentials.defaults() => const AlpacaCredentials(
        apiUrl: paperUrl,
        apiKey: '',
        apiSecret: '',
      );

  AlpacaCredentials copyWith({
    String? apiUrl,
    String? apiKey,
    String? apiSecret,
    String? dataFeed,
    String? optionFeed,
  }) {
    return AlpacaCredentials(
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      dataFeed: dataFeed ?? this.dataFeed,
      optionFeed: optionFeed ?? this.optionFeed,
    );
  }
}

enum AlpacaEnv { paper, live }

AlpacaEnv alpacaEnvFromUrl(String url) =>
    url.contains('paper') ? AlpacaEnv.paper : AlpacaEnv.live;

String alpacaUrlForEnv(AlpacaEnv env) =>
    env == AlpacaEnv.paper ? AlpacaCredentials.paperUrl : AlpacaCredentials.liveUrl;
