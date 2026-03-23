// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_budget_flutter/main.dart';

void main() {
  testWidgets('App should load', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BudgetApp());

    // Verify that our app starts with the home page
    expect(find.text('Family Budget'), findsOneWidget);
  });
}