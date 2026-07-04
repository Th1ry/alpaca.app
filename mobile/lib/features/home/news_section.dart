import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_settings.dart';
import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/translated_news_provider.dart';
import '../../shared/widgets/okx_ui.dart';
import 'news_detail_screen.dart';
import 'news_text.dart';

class NewsSection extends ConsumerWidget {
  const NewsSection({super.key});

  bool _autoTranslate(AppSettings settings) =>
      settings.language == AppLanguage.zh && settings.autoTranslateNews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final newsAsync = ref.watch(newsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OkxSectionHeader(title: S.news),
        const SizedBox(height: 4),
        if (_autoTranslate(settings))
          ref.watch(displayNewsProvider).when(
                loading: () => const _NewsLoading(),
                error: (_, __) => newsAsync.when(
                  loading: () => const _NewsLoading(),
                  error: (_, __) => _NewsError(),
                  data: (items) => _NewsList.fromRaw(items),
                ),
                data: (display) => _NewsList.fromDisplay(display),
              )
        else
          newsAsync.when(
            loading: () => const _NewsLoading(),
            error: (_, __) => _NewsError(),
            data: (items) => _NewsList.fromRaw(items),
          ),
      ],
    );
  }
}

class _NewsLoading extends StatelessWidget {
  const _NewsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _NewsError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(S.newsLoadFailed, style: TextStyle(color: AppColors.muted, fontSize: 12)),
    );
  }
}

class _NewsList extends StatelessWidget {
  const _NewsList._(this.tiles);

  factory _NewsList.fromRaw(List<NewsItem> items) {
    if (items.isEmpty) return _NewsList._(const []);
    return _NewsList._(
      items
          .take(8)
          .map((n) => _NewsTile(item: n, headline: n.headline, preview: newsPreviewText(n)))
          .toList(),
    );
  }

  factory _NewsList.fromDisplay(List<DisplayNewsItem> items) {
    if (items.isEmpty) return _NewsList._(const []);
    return _NewsList._(
      items
          .map((n) => _NewsTile(item: n.item, headline: n.headline, preview: n.preview))
          .toList(),
    );
  }

  final List<_NewsTile> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(S.noNews, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      );
    }
    return GlassListGroup(children: tiles);
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({
    required this.item,
    required this.headline,
    required this.preview,
  });

  final NewsItem item;
  final String headline;
  final String preview;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = item.createdAt > 0
        ? DateFormat('MM/dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(item.createdAt * 1000, isUtc: true)
                .add(const Duration(hours: 8)),
          )
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.35),
              ),
              if (preview.isNotEmpty && preview != headline) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.source.isNotEmpty)
                    Expanded(
                      child: Text(
                        item.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                    ),
                  if (item.symbols.isNotEmpty)
                    Text(
                      item.symbols.take(3).join(', '),
                      style: TextStyle(color: AppColors.muted2, fontSize: 10),
                    ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(time, style: TextStyle(color: AppColors.muted2, fontSize: 10)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
