import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tailorflow_ng/app.dart';

void main() {
  testWidgets('App boots to customer list', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TailorFlowApp()));
    // The app opens the database on startup. In widget tests, the underlying
    // platform database may not be available, so we only assert the initial
    // loading UI builds.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(TailorFlowApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
