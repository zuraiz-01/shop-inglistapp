import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shopping_list_app/features/auth/providers/auth_provider.dart';
import 'package:shopping_list_app/features/auth/screens/splash_screen.dart';

void main() {
  testWidgets('shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.test(),
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    expect(find.text('Shared Shopping Lists'), findsOneWidget);
    expect(find.text('Loading your session'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
