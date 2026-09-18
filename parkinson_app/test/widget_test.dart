import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parkinson_app/app.dart';

void main() {
  testWidgets('App boots to sign-in when signed out',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ParkinsonApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });
}
