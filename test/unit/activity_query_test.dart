import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerone/features/transactions/domain/activity_query.dart';
import 'package:ledgerone/features/transactions/domain/money_transaction.dart';

void main() {
  MoneyTransaction entry(
    String id,
    DateTime date,
    TransactionType type,
    double amount,
  ) => MoneyTransaction(
    id: id,
    accountId: 'cash',
    categoryId: 'food',
    amount: amount,
    transactionType: type,
    transferAccountId: type == TransactionType.transfer ? 'bank' : null,
    createdAt: date,
  );
  final entries = [
    entry(
      'expense',
      DateTime(2026, 10, 1, 23, 59),
      TransactionType.expense,
      0.1,
    ),
    entry('expense2', DateTime(2026, 10, 2), TransactionType.expense, 0.2),
    entry('income', DateTime(2026, 10, 1), TransactionType.income, 100),
    entry('transfer', DateTime(2026, 10, 1), TransactionType.transfer, 20),
  ];
  test('date scope includes full end day and excludes following day', () {
    final result = queryActivity(
      entries,
      startDate: '2026-10-01',
      endDate: '2026-10-01',
    );
    expect(result.length, 3);
    expect(activityTotals(result), {
      'count': 3,
      'income': 100.0,
      'expense': 0.1,
      'transfers': 20.0,
    });
  });
  test(
    'transfers match destination account and do not inflate income or expense',
    () {
      final result = queryActivity(entries, accountId: 'bank');
      expect(activityTotals(result), {
        'count': 1,
        'income': 0.0,
        'expense': 0.0,
        'transfers': 20.0,
      });
      expect(activityTotals(entries)['expense'], 0.3);
    },
  );
  test(
    'invalid and inverted dates fail instead of silently broadening export',
    () {
      for (final date in ['2026-02-31', 'October', '2026-13-01']) {
        expect(() => queryActivity(entries, startDate: date), throwsStateError);
      }
      expect(
        () => queryActivity(
          entries,
          startDate: '2026-10-02',
          endDate: '2026-10-01',
        ),
        throwsStateError,
      );
    },
  );
}
