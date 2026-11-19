import '../../../core/utils/money.dart';
import 'money_transaction.dart';

/// Returns the balance change for every account affected by [transaction].
///
/// Passing [reverse] undoes the original posting. Keeping this calculation
/// pure gives Firebase and demo mode one source of truth for ledger updates.
Map<String, double> transactionBalanceDeltas(
  MoneyTransaction transaction, {
  bool reverse = false,
}) {
  final direction = reverse ? -1.0 : 1.0;

  switch (transaction.transactionType) {
    case TransactionType.income:
      return {transaction.accountId: transaction.amount * direction};
    case TransactionType.expense:
      return {transaction.accountId: -transaction.amount * direction};
    case TransactionType.transfer:
      final destinationId = transaction.transferAccountId;
      if (destinationId == null || destinationId.isEmpty) {
        throw StateError('A transfer requires a destination account.');
      }
      if (destinationId == transaction.accountId) {
        throw StateError('Transfer accounts must be different.');
      }
      return {
        transaction.accountId: -transaction.amount * direction,
        destinationId: transaction.amount * direction,
      };
  }
}

Map<String, double> combineBalanceDeltas(
  Iterable<Map<String, double>> changes,
) {
  final combined = <String, double>{};
  for (final change in changes) {
    for (final entry in change.entries) {
      combined.update(
        entry.key,
        (value) => Money.add(value, entry.value),
        ifAbsent: () => entry.value,
      );
    }
  }
  combined.removeWhere((_, value) => value == 0);
  return combined;
}
