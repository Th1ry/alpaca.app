import 'package:dio/dio.dart';

import '../core/alpaca_config.dart';

class AlpacaApiException implements Exception {
  AlpacaApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class AlpacaConnectionInfo {
  const AlpacaConnectionInfo.success({
    required this.paper,
    required this.equity,
    this.status,
  })  : ok = true,
        error = null;

  const AlpacaConnectionInfo.failure(this.error)
      : ok = false,
        paper = false,
        equity = 0,
        status = null;

  final bool ok;
  final bool paper;
  final double equity;
  final String? status;
  final String? error;
}

class AlpacaClient {
  AlpacaClient(AlpacaCredentials creds)
      : _creds = creds,
        _trading = Dio(
          BaseOptions(
            baseUrl: creds.tradingBase,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 25),
            headers: _headers(creds),
          ),
        ),
        _data = Dio(
          BaseOptions(
            baseUrl: AlpacaCredentials.dataBase,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 25),
            headers: _headers(creds),
          ),
        );

  final AlpacaCredentials _creds;
  final Dio _trading;
  final Dio _data;

  static Map<String, String> _headers(AlpacaCredentials creds) => {
        'APCA-API-KEY-ID': creds.apiKey,
        'APCA-API-SECRET-KEY': creds.apiSecret,
        'Accept': 'application/json',
      };

  bool get configured => _creds.isConfigured;

  /// Verifies credentials against Alpaca trading + market data APIs.
  Future<AlpacaConnectionInfo> testConnection() async {
    if (!_creds.isConfigured) {
      return const AlpacaConnectionInfo.failure('missing_keys');
    }
    try {
      final data = await tradingGet('/v2/account') as Map<String, dynamic>;
      final equity = double.tryParse('${data['equity']}') ?? 0;
      try {
        await dataGet(
          '/v2/stocks/AAPL/bars?symbols=AAPL&timeframe=1Day&limit=1&feed=${_creds.dataFeed}',
        );
      } on AlpacaApiException catch (e) {
        return AlpacaConnectionInfo.failure('Market data: ${e.message}');
      }
      return AlpacaConnectionInfo.success(
        paper: _creds.isPaper,
        equity: equity,
        status: '${data['status'] ?? ''}',
      );
    } on AlpacaApiException catch (e) {
      return AlpacaConnectionInfo.failure(e.message);
    } catch (e) {
      return AlpacaConnectionInfo.failure(e.toString());
    }
  }

  Future<dynamic> tradingGet(String path) => _request(_trading, 'GET', path);

  Future<dynamic> tradingPost(String path, {Map<String, dynamic>? body}) =>
      _request(_trading, 'POST', path, body: body);

  Future<dynamic> tradingDelete(String path) =>
      _request(_trading, 'DELETE', path);

  Future<dynamic> dataGet(String path) => _request(_data, 'GET', path);

  Future<dynamic> _request(
    Dio dio,
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!_creds.isConfigured) {
      throw AlpacaApiException(503, 'Alpaca API not configured');
    }
    try {
      final resp = await dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      if (resp.data == null || resp.data == '') return {};
      return resp.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      String msg;
      if (data is Map) {
        msg = (data['message'] ?? data['error'] ?? e.message ?? 'HTTP $status').toString();
      } else {
        msg = e.message ?? 'HTTP $status';
      }
      throw AlpacaApiException(status, msg);
    }
  }
}
