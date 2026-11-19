import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledgerone/core/providers/app_providers.dart';
import 'package:ledgerone/core/providers/demo_store.dart';
import 'package:ledgerone/features/accounts/domain/account.dart';
import 'package:ledgerone/features/transactions/data/transactions_repository.dart';
import 'package:ledgerone/features/transactions/domain/money_transaction.dart';
import 'package:ledgerone/features/transactions/presentation/screens/transaction_form_screen.dart';

class DelayedRepository extends TransactionsRepository {
  DelayedRepository(super.ref, this.existing);
  final MoneyTransaction? existing;
  MoneyTransaction? updated;
  int creates = 0;
  @override
  Future<MoneyTransaction?> getById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return existing;
  }

  @override
  Future<MoneyTransaction> update(MoneyTransaction tx) async {
    updated = tx;
    return tx;
  }

  @override
  Future<MoneyTransaction> create(MoneyTransaction tx) async {
    creates++;
    return tx;
  }
}

void main() {
  for (final width in [800.0, 360.0]) {
    testWidgets('cold transfer edit preserves data at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = DemoStore.instance;
      await store.deleteAccount();
      await store.register(
        name: 'Test',
        email: 'test@example.com',
        password: 'Password1',
      );
      final source = store.accounts.first;
      await store.upsertAccount(
        const Account(
          id: 'destination',
          accountName: 'Bank',
          accountType: AccountType.bank,
          balance: 100,
        ),
      );
      final tx = MoneyTransaction(
        id: 'transfer',
        accountId: source.id,
        transferAccountId: 'destination',
        categoryId: '',
        amount: 25,
        transactionType: TransactionType.transfer,
        createdAt: DateTime(2026, 10, 1),
        receiptUrl: 'https://example.com/receipt',
        tags: const ['moving'],
      );
      late DelayedRepository repo;
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder: (_, _) =>
                const TransactionFormScreen(transactionId: 'transfer'),
          ),
          GoRoute(
            path: '/transactions',
            builder: (_, _) => const Scaffold(body: Text('Saved activity')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBackendProvider.overrideWithValue(
              AppBackend(mode: BackendMode.demo),
            ),
            transactionsRepositoryProvider.overrideWith(
              (ref) => repo = DelayedRepository(ref, tx),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.text('Save'), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Edit transaction'), findsOneWidget);
      await tester.ensureVisible(find.text('Update'));
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(repo.creates, 0);
      expect(repo.updated?.transactionType, TransactionType.transfer);
      expect(repo.updated?.transferAccountId, 'destination');
      expect(repo.updated?.receiptUrl, tx.receiptUrl);
      expect(repo.updated?.tags, tx.tags);
      expect(tester.takeException(), isNull);
    });
  }
}
