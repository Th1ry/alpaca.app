import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';

/// Cached news list (summary only). Invalidate on home pull-to-refresh.
final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  return ref.read(apiServiceProvider).getNews(limit: 8);
});
