import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';

final newsProvider = FutureProvider.autoDispose<List<NewsItem>>((ref) async {
  return ref.read(apiServiceProvider).getNews(limit: 12);
});
