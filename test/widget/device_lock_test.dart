import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerone/core/services/device_lock.dart';
import 'package:ledgerone/core/shell/device_lock_gate.dart';

void main() {
  testWidgets('PIN gates private content and relocks after backgrounding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceLockProvider(
            'user',
          ).overrideWith((ref) async => const DeviceLock(pin: '1234')),
        ],
        child: const MaterialApp(
          home: DeviceLockGate(
            uid: 'user',
            child: Scaffold(body: Text('Private balance')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private balance'), findsNothing);
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Private balance'), findsNothing);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Private balance'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Private balance'), findsNothing);
    expect(find.text('Unlock LedgerOne'), findsOneWidget);
  });

  testWidgets('lock read errors fail closed with retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceLockProvider(
            'user',
          ).overrideWith((ref) => throw StateError('storage unavailable')),
        ],
        child: const MaterialApp(
          home: DeviceLockGate(uid: 'user', child: Text('Private balance')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private balance'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}
