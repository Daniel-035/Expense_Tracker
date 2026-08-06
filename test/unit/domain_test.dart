import 'package:flutter_test/flutter_test.dart';

import 'package:ledgerone/features/budgets/domain/budget.dart';
import 'package:ledgerone/features/goals/domain/savings_goal.dart';
import 'package:ledgerone/features/transactions/domain/money_transaction.dart';
import 'package:ledgerone/core/utils/validators.dart';
import 'package:ledgerone/shared/formatters/currency_formatter.dart';

void main() {
  group('Validators', () {
    test('email validation', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('user@ledgerone.app'), isNull);
    });

    test('password validation', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('password'), isNotNull);
      expect(Validators.password('Password1'), isNull);
    });

    test('amount validation', () {
      expect(Validators.amount(''), isNotNull);
      expect(Validators.amount('-1'), isNotNull);
      expect(Validators.amount('NaN'), isNotNull);
      expect(Validators.amount('Infinity'), isNotNull);
      expect(Validators.amount('12.50'), isNull);
    });
  });

  group('Budget', () {
    test('remaining and exceeded', () {
      const b = Budget(
        id: '1',
        amount: 1000,
        period: BudgetPeriod.monthly,
        monthKey: '2026-07',
        spent: 1200,
      );
      expect(b.isExceeded, isTrue);
      expect(b.remaining, -200);
      expect(b.progress, greaterThan(1));
    });

    test('counts expenses from every selected category', () {
      const budget = Budget(
        id: 'multi',
        categoryIds: ['food', 'travel'],
        amount: 1000,
        period: BudgetPeriod.monthly,
        monthKey: '2026-08',
      );
      final transactions = [
        MoneyTransaction(
          id: 'food-expense',
          accountId: 'account',
          categoryId: 'food',
          amount: 100,
          transactionType: TransactionType.expense,
          createdAt: DateTime(2026, 8, 2),
        ),
        MoneyTransaction(
          id: 'travel-expense',
          accountId: 'account',
          categoryId: 'travel',
          amount: 250,
          transactionType: TransactionType.expense,
          createdAt: DateTime(2026, 8, 3),
        ),
        MoneyTransaction(
          id: 'other-expense',
          accountId: 'account',
          categoryId: 'shopping',
          amount: 500,
          transactionType: TransactionType.expense,
          createdAt: DateTime(2026, 8, 4),
        ),
        MoneyTransaction(
          id: 'food-income',
          accountId: 'account',
          categoryId: 'food',
          amount: 1000,
          transactionType: TransactionType.income,
          createdAt: DateTime(2026, 8, 5),
        ),
      ];

      final live = budget.withLiveSpent(
        transactions,
        now: DateTime(2026, 8, 6),
      );

      expect(live.spent, 350);
      expect(live.remaining, 650);
    });

    test('loads legacy single-category budget data', () {
      final budget = Budget.fromMap('legacy', {
        'categoryId': 'food',
        'amount': 500,
        'period': 'monthly',
        'monthKey': '2026-08',
      });

      expect(budget.categoryIds, ['food']);
      expect(budget.toMap()['categoryIds'], ['food']);
    });
  });

  group('SavingsGoal', () {
    test('progress clamps at 1', () {
      final g = SavingsGoal(
        id: '1',
        goalName: 'Emergency',
        targetAmount: 1000,
        savedAmount: 1500,
        deadline: DateTime(2026, 12, 31),
      );
      expect(g.isComplete, isTrue);
      expect(g.progress, 1);
    });
  });

  group('CurrencyFormatter', () {
    test('formats INR', () {
      final text = CurrencyFormatter.format(1234.5, currency: 'INR');
      expect(text.contains('1'), isTrue);
    });
  });
}
