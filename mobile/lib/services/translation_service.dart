import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final translationServiceProvider = Provider<TranslationService>((ref) {
  final service = TranslationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Free EN→ZH translation via MyMemory (no API key). Results are cached in memory.
class TranslationService {
  TranslationService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final _cache = <String, String>{};
  final _inFlight = <String, Future<String>>{};

  static const _maxChunk = 450;

  void dispose() {
    _dio.close(force: true);
  }

  Future<String> translateEnToZh(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    if (_looksChinese(trimmed)) return text;

    final cached = _cache[trimmed];
    if (cached != null) return cached;

    final pending = _inFlight[trimmed];
    if (pending != null) return pending;

    final task = _translateLong(trimmed);
    _inFlight[trimmed] = task;
    try {
      final out = await task;
      _cache[trimmed] = out;
      return out;
    } finally {
      _inFlight.remove(trimmed);
    }
  }

  bool _looksChinese(String text) {
    var cjk = 0;
    var letters = 0;
    for (final c in text.runes) {
      if (c >= 0x4E00 && c <= 0x9FFF) {
        cjk++;
      } else if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
        letters++;
      }
    }
    if (letters == 0) return true;
    return cjk / (cjk + letters) > 0.35;
  }

  Future<String> _translateLong(String text) async {
    if (text.length <= _maxChunk) return _translateChunk(text);

    final parts = <String>[];
    for (final block in text.split(RegExp(r'\n\s*\n'))) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.length <= _maxChunk) {
        parts.add(await _translateChunk(trimmed));
      } else {
        final buf = StringBuffer();
        for (var i = 0; i < trimmed.length; i += _maxChunk) {
          final end = (i + _maxChunk > trimmed.length) ? trimmed.length : i + _maxChunk;
          buf.write(await _translateChunk(trimmed.substring(i, end)));
          if (end < trimmed.length) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        parts.add(buf.toString());
      }
    }
    return parts.join('\n\n');
  }

  Future<String> _translateChunk(String text) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://api.mymemory.translated.net/get',
        queryParameters: {'q': text, 'langpair': 'en|zh-CN'},
        options: Options(
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );
      final data = resp.data;
      final translated = data?['responseData']?['translatedText'] as String?;
      if (translated == null || translated.trim().isEmpty) return text;
      final upper = translated.toUpperCase();
      if (upper.contains('QUOTA') || upper.contains('MYMEMORY WARNING')) return text;
      return translated.trim();
    } catch (_) {
      return text;
    }
  }
}
