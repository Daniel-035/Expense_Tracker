import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledgerone/core/providers/app_providers.dart';
import 'package:ledgerone/core/theme/app_theme.dart';
import 'package:ledgerone/features/auth/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Login screen renders LedgerOne branding', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBackendProvider.overrideWithValue(
            AppBackend(mode: BackendMode.demo),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('LedgerOne'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
