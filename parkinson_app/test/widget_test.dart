import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parkinson_app/app.dart';

void main() {
  testWidgets('App boots to ParkinTrace BEGIN when signed out',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ParkinsonApp()));
    await tester.pumpAndSettle();

    expect(find.text('ParkinTrace'), findsWidgets);
    expect(find.text('BEGIN'), findsOneWidget);
  });
}
