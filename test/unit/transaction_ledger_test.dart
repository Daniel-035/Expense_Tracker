import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerone/features/transactions/domain/money_transaction.dart';
import 'package:ledgerone/features/transactions/domain/transaction_ledger.dart';

MoneyTransaction transaction({
  required TransactionType type,
  double amount = 100,
  String accountId = 'from',
  String? transferAccountId,
}) {
  return MoneyTransaction(
    id: 'tx',
    accountId: accountId,
    categoryId: 'category',
    amount: amount,
    transactionType: type,
    transferAccountId: transferAccountId,
    createdAt: DateTime(2026, 8, 6),
  );
}

void main() {
  group('transactionBalanceDeltas', () {
    test('income credits its account and can be reversed', () {
      final income = transaction(type: TransactionType.income);

      expect(transactionBalanceDeltas(income), {'from': 100});
      expect(transactionBalanceDeltas(income, reverse: true), {'from': -100});
    });

    test('expense debits its account and can be reversed', () {
      final expense = transaction(type: TransactionType.expense);

      expect(transactionBalanceDeltas(expense), {'from': -100});
      expect(transactionBalanceDeltas(expense, reverse: true), {'from': 100});
    });

    test('transfer debits source and credits destination', () {
      final transfer = transaction(
        type: TransactionType.transfer,
        transferAccountId: 'to',
      );

      expect(transactionBalanceDeltas(transfer), {'from': -100, 'to': 100});
      expect(transactionBalanceDeltas(transfer, reverse: true), {
        'from': 100,
        'to': -100,
      });
    });

    test('invalid transfers are rejected', () {
      expect(
        () => transactionBalanceDeltas(
          transaction(type: TransactionType.transfer),
        ),
        throwsStateError,
      );
      expect(
        () => transactionBalanceDeltas(
          transaction(
            type: TransactionType.transfer,
            transferAccountId: 'from',
          ),
        ),
        throwsStateError,
      );
    });

    test('combines reverse-old and apply-new balance changes', () {
      final oldExpense = transaction(
        type: TransactionType.expense,
        accountId: 'old',
      );
      final newExpense = transaction(
        type: TransactionType.expense,
        accountId: 'new',
        amount: 150,
      );

      expect(
        combineBalanceDeltas([
          transactionBalanceDeltas(oldExpense, reverse: true),
          transactionBalanceDeltas(newExpense),
        ]),
        {'old': 100, 'new': -150},
      );
    });
  });
}
