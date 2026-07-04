import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/translated_news_provider.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/okx_ui.dart';
import '../../shared/widgets/widgets.dart';
import 'news_text.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  NewsItem? _item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    if (_item!.bodyText.isEmpty && _item!.id.isNotEmpty) {
      _loadFull();
    }
  }

  Future<void> _loadFull() async {
    setState(() => _loading = true);
    try {
      final full = await ref.read(apiServiceProvider).getNewsById(_item!.id);
      if (mounted && full != null) setState(() => _item = full);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openOriginal() async {
    final url = _item?.url ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final item = _item ?? widget.item;
    final time = item.createdAt > 0
        ? DateFormat('yyyy/MM/dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(item.createdAt * 1000, isUtc: true)
                .add(const Duration(hours: 8)),
          )
        : '';
    final body = stripNewsHtml(item.bodyText);
    final headlineAsync = ref.watch(translatedNewsHeadlineProvider(item.headline));
    final bodyAsync = ref.watch(translatedNewsBodyProvider(body));

    return Scaffold(
      appBar: AppBar(title: Text(S.newsDetail)),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassAmbientLayer()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              headlineAsync.when(
                loading: () => Text(
                  item.headline,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                ),
                error: (_, __) => Text(
                  item.headline,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                ),
                data: (headline) => Text(
                  headline,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              GlassPanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item.source.isNotEmpty)
                      Text(item.source, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    if (time.isNotEmpty) ...[
                      if (item.source.isNotEmpty) const SizedBox(height: 4),
                      Text(time, style: TextStyle(color: AppColors.muted2, fontSize: 11)),
                    ],
                    if (item.symbols.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${S.newsRelatedSymbols}: ${item.symbols.join(', ')}',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (body.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(S.newsNoContent, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                )
              else
                bodyAsync.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(S.newsTranslating, style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  error: (_, __) => Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
                  data: (translated) => Text(
                    translated,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              if (item.url.isNotEmpty) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _openOriginal,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(S.newsOpenOriginal),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
