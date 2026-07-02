import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alpaca_options_app/app.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AlpacaOptionsApp()));
    expect(find.text('首页'), findsOneWidget);
  });
}
