import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onterra/main.dart';

void main() {
  testWidgets('welcome screen renders and leads to sign in', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OnterraApp()));
    await tester.pumpAndSettle();
    expect(find.text('Onterra'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with your phone'), findsOneWidget);
  });
}
