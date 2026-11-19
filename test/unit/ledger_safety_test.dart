import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledgerone/core/providers/app_providers.dart';
import 'package:ledgerone/core/providers/demo_store.dart';
import 'package:ledgerone/core/utils/money.dart';
import 'package:ledgerone/core/utils/recurrence.dart';
import 'package:ledgerone/features/accounts/data/accounts_repository.dart';
import 'package:ledgerone/features/accounts/domain/account.dart';
import 'package:ledgerone/features/bills/data/bills_repository.dart';
import 'package:ledgerone/features/categories/domain/category.dart';
import 'package:ledgerone/features/transactions/data/transactions_repository.dart';
import 'package:ledgerone/features/transactions/domain/money_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  final store = DemoStore.instance;
  late Account account;
  MoneyTransaction expense({double amount = 10}) => MoneyTransaction(
    id: 'operation',
    accountId: account.id,
    categoryId: 'food',
    amount: amount,
    transactionType: TransactionType.expense,
    createdAt: DateTime(2026, 10, 1),
    receiptUrl: 'https://example.com/receipt',
    tags: const ['work'],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.deleteAccount();
    await store.register(
      name: 'Test',
      email: 'test@example.com',
      password: 'Password1',
    );
    container = ProviderContainer(
      overrides: [
        appBackendProvider.overrideWithValue(
          AppBackend(mode: BackendMode.demo),
        ),
      ],
    );
    account = store.accounts.first;
  });
  tearDown(() => container.dispose());

  test(
    'replaying create posts exactly once, conflicting payload is rejected',
    () async {
      final repo = container.read(transactionsRepositoryProvider);
      await repo.create(expense());
      await repo.create(expense());
      expect(store.transactions.length, 1);
      expect(store.accounts.first.balance, -10);
      await expectLater(repo.create(expense(amount: 20)), throwsStateError);
      expect(store.accounts.first.balance, -10);
    },
  );

  test(
    'metadata edits preserve a balance changed after the form opened',
    () async {
      await container.read(transactionsRepositoryProvider).create(expense());
      await container
          .read(accountsRepositoryProvider)
          .update(account.copyWith(accountName: 'Renamed'));
      expect(store.accounts.first.balance, -10);
      expect(store.accounts.first.accountName, 'Renamed');
    },
  );

  test('archiving keeps ledger references valid and can be undone', () async {
    final txRepo = container.read(transactionsRepositoryProvider);
    final accounts = container.read(accountsRepositoryProvider);
    await txRepo.create(expense());
    await accounts.delete(account.id);
    expect(store.accounts.first.archived, isTrue);
    await txRepo.delete('operation');
    expect(store.accounts.first.balance, 0);
    await accounts.setArchived(account.id, false);
    expect(store.accounts.first.archived, isFalse);
  });

  test('failed demo posting leaves history and balances unchanged', () async {
    await expectLater(
      store.upsertTransaction(expense().copyWith(accountId: 'missing')),
      throwsStateError,
    );
    expect(store.transactions, isEmpty);
    expect(store.accounts.first.balance, 0);
  });

  test('serialization migrates legacy decimals and preserves all metadata', () {
    final original = expense();
    final map = original.toMap();
    expect(map['amountMinor'], 1000);
    expect(MoneyTransaction.fromMap(original.id, map), original);
    map.remove('amountMinor');
    expect(MoneyTransaction.fromMap(original.id, map), original);
    expect(original.copyWith(receiptUrl: null).receiptUrl, isNull);
    expect(original.copyWith(amount: 12).receiptUrl, original.receiptUrl);
    expect(original.copyWith(tags: const ['changed']), isNot(original));
  });

  test('minor-unit arithmetic rejects invalid values and is exact', () {
    expect(Money.add(0.1, 0.2), 0.3);
    expect(Money.sum([0.1, 0.2, 0.3]), 0.6);
    for (final value in [double.nan, double.infinity, 0.001, 90000000001.0]) {
      expect(() => Money.minor(value), throwsStateError);
    }
    expect(() => Money.minor(0, positive: true), throwsStateError);
    expect(Money.minor(-12.34), -1234);
  });

  test('monthly dates clamp and retain the original billing day', () {
    final feb = nextOccurrence(
      DateTime(2027, 1, 31),
      RecurrenceInterval.monthly,
    );
    expect(feb, DateTime(2027, 2, 28));
    expect(
      nextOccurrence(feb, RecurrenceInterval.monthly, anchorDay: 31),
      DateTime(2027, 3, 31),
    );
    expect(
      nextOccurrence(DateTime(2028, 2, 29), RecurrenceInterval.yearly),
      DateTime(2029, 2, 28),
    );
  });

  test(
    'bill payment records exactly one expense per cycle and retains month-end anchor',
    () async {
      final repo = container.read(billsRepositoryProvider);
      final category = store.categories.firstWhere(
        (c) => c.type == CategoryType.expense,
      );
      final bill = await repo.create(
        title: 'Rent',
        amount: 10,
        dueDate: DateTime(2027, 1, 31),
      );
      final feb = await repo.markPaid(
        bill,
        accountId: account.id,
        categoryId: category.id,
      );
      await repo.markPaid(bill, accountId: account.id, categoryId: category.id);
      expect(store.transactions.length, 1);
      expect(store.accounts.first.balance, -10);
      expect(feb.dueDate, DateTime(2027, 2, 28));
      final march = await repo.markPaid(
        feb,
        accountId: account.id,
        categoryId: category.id,
      );
      expect(store.transactions.length, 2);
      expect(store.accounts.first.balance, -20);
      expect(march.dueDate, DateTime(2027, 3, 31));
    },
  );
}
