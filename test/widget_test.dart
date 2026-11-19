import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledgerone/core/providers/app_providers.dart';
import 'package:ledgerone/core/providers/demo_store.dart';
import 'package:ledgerone/core/services/device_lock.dart';
import 'package:ledgerone/main.dart';

void main() {
  testWidgets(
    'phone user can add an expense from Home and return with updated balance',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = DemoStore.instance;
      await store.deleteAccount();
      final user = await store.register(
        name: 'Test User',
        email: 'test@example.com',
        password: 'Password1',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBackendProvider.overrideWithValue(
              AppBackend(mode: BackendMode.demo),
            ),
            deviceLockProvider(
              user.id,
            ).overrideWith((ref) async => const DeviceLock()),
          ],
          child: const LedgerOneApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '12.34');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.transactions.length, 1);
      expect(store.accounts.first.balance, -12.34);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
