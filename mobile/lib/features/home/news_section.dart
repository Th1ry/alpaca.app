import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../shared/widgets/okx_ui.dart';

class NewsSection extends ConsumerWidget {
  const NewsSection({super.key, this.onSymbolTap});

  final void Function(String symbol)? onSymbolTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OkxSectionHeader(title: S.news),
        const SizedBox(height: 4),
        newsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(S.newsLoadFailed, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(S.noNews, style: TextStyle(color: AppColors.muted, fontSize: 12)),
              );
            }
            return GlassListGroup(
              children: items
                  .take(8)
                  .map((n) => _NewsTile(item: n, onSymbolTap: onSymbolTap))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.item, this.onSymbolTap});

  final NewsItem item;
  final void Function(String symbol)? onSymbolTap;

  @override
  Widget build(BuildContext context) {
    final time = item.createdAt > 0
        ? DateFormat('MM/dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(item.createdAt * 1000, isUtc: true)
                .add(const Duration(hours: 8)),
          )
        : '';
    final sym = item.symbols.isNotEmpty ? item.symbols.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: sym != null && onSymbolTap != null ? () => onSymbolTap!(sym) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.35),
              ),
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
                  if (sym != null)
                    Text(
                      sym,
                      style: TextStyle(color: AppColors.accentSoft, fontSize: 10, fontWeight: FontWeight.w600),
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
