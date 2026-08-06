import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerone/features/transactions/domain/money_transaction.dart';
import 'package:ledgerone/shared/filters/transaction_date_filter.dart';

MoneyTransaction transactionAt(String id, DateTime createdAt) {
  return MoneyTransaction(
    id: id,
    accountId: 'account',
    categoryId: 'category',
    amount: 10,
    transactionType: TransactionType.expense,
    createdAt: createdAt,
  );
}

void main() {
  group('TransactionDateFilter', () {
    test('day includes only the selected calendar day', () {
      final filter = TransactionDateFilter(
        preset: DateFilterPreset.day,
        anchor: DateTime(2026, 8, 6, 15),
      );

      expect(filter.matches(DateTime(2026, 8, 6)), isTrue);
      expect(filter.matches(DateTime(2026, 8, 6, 23, 59, 59)), isTrue);
      expect(filter.matches(DateTime(2026, 8, 7)), isFalse);
    });

    test('month uses inclusive start and exclusive next month', () {
      final filter = TransactionDateFilter.currentMonth(DateTime(2026, 8, 20));

      expect(filter.matches(DateTime(2026, 8, 1)), isTrue);
      expect(filter.matches(DateTime(2026, 8, 31, 23, 59)), isTrue);
      expect(filter.matches(DateTime(2026, 9, 1)), isFalse);
    });

    test('year includes the full selected year', () {
      final filter = TransactionDateFilter(
        preset: DateFilterPreset.year,
        anchor: DateTime(2026, 8, 6),
      );

      expect(filter.matches(DateTime(2026, 1, 1)), isTrue);
      expect(filter.matches(DateTime(2026, 12, 31, 23, 59)), isTrue);
      expect(filter.matches(DateTime(2027, 1, 1)), isFalse);
    });

    test('custom range includes the complete end date', () {
      final filter = TransactionDateFilter.custom(
        DateTime(2026, 8, 15),
        DateTime(2026, 8, 1),
      );

      expect(filter.matches(DateTime(2026, 8, 1)), isTrue);
      expect(filter.matches(DateTime(2026, 8, 15, 23, 59)), isTrue);
      expect(filter.matches(DateTime(2026, 8, 16)), isFalse);
    });

    test('previous and next navigate the selected period', () {
      final month = TransactionDateFilter.currentMonth(DateTime(2026, 1, 31));

      expect(month.shift(-1).range.start, DateTime(2025, 12, 1));
      expect(month.shift(1).range.start, DateTime(2026, 2, 1));
    });

    test('filters a transaction collection', () {
      final filter = TransactionDateFilter.currentMonth(DateTime(2026, 8, 6));
      final transactions = [
        transactionAt('july', DateTime(2026, 7, 31)),
        transactionAt('august', DateTime(2026, 8, 10)),
        transactionAt('september', DateTime(2026, 9, 1)),
      ];

      expect(
        filterTransactionsByDate(
          transactions,
          filter,
        ).map((transaction) => transaction.id),
        ['august'],
      );
    });
  });
}
