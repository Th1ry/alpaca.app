import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_settings.dart';
import '../features/home/news_text.dart';
import '../models/models.dart';
import '../providers/app_settings_provider.dart';
import '../providers/news_provider.dart';
import '../services/translation_service.dart';

class DisplayNewsItem {
  const DisplayNewsItem({
    required this.item,
    required this.headline,
    required this.preview,
  });

  final NewsItem item;
  final String headline;
  final String preview;
}

final displayNewsProvider = FutureProvider<List<DisplayNewsItem>>((ref) async {
  ref.watch(appSettingsProvider.select((s) => '${s.language.name}:${s.autoTranslateNews}'));
  final items = await ref.watch(newsProvider.future);
  final visible = items.take(8).toList();
  final translator = ref.read(translationServiceProvider);

  Future<DisplayNewsItem> mapItem(NewsItem item) async {
    final rawPreview = newsPreviewText(item);
    final headline = await translator.translateEnToZh(item.headline);
    final preview = rawPreview == item.headline ? headline : await translator.translateEnToZh(rawPreview);
    return DisplayNewsItem(item: item, headline: headline, preview: preview);
  }

  const batchSize = 3;
  final out = <DisplayNewsItem>[];
  for (var i = 0; i < visible.length; i += batchSize) {
    final batch = visible.skip(i).take(batchSize).toList();
    out.addAll(await Future.wait(batch.map(mapItem)));
  }
  return out;
});

final translatedNewsBodyProvider = FutureProvider.family<String, String>((ref, body) async {
  final settings = ref.watch(appSettingsProvider.select((s) => s.autoTranslateNews));
  if (ref.read(appSettingsProvider).language != AppLanguage.zh ||
      !settings ||
      body.trim().isEmpty) {
    return body;
  }
  return ref.read(translationServiceProvider).translateEnToZh(body);
});

final translatedNewsHeadlineProvider = FutureProvider.family<String, String>((ref, headline) async {
  final settings = ref.watch(appSettingsProvider.select((s) => s.autoTranslateNews));
  if (ref.read(appSettingsProvider).language != AppLanguage.zh ||
      !settings ||
      headline.trim().isEmpty) {
    return headline;
  }
  return ref.read(translationServiceProvider).translateEnToZh(headline);
});
