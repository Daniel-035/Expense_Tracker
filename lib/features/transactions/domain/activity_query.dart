import '../../../core/utils/money.dart';
import 'money_transaction.dart';

/// Deterministic query used by AI tools. End dates include the whole day.
List<MoneyTransaction> queryActivity(
  List<MoneyTransaction> entries, {
  String startDate = '',
  String endDate = '',
  String accountId = '',
  String categoryId = '',
}) {
  DateTime? date(String raw) {
    if (raw.isEmpty) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw StateError('Use dates in YYYY-MM-DD format.');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != raw) {
      throw StateError('Invalid date.');
    }
    return parsed;
  }

  final start = date(startDate);
  final last = date(endDate);
  if (start != null && last != null && last.isBefore(start)) {
    throw StateError('End date must follow start date.');
  }
  final end = last == null
      ? null
      : DateTime(last.year, last.month, last.day + 1);
  final selected = entries
      .where(
        (t) =>
            (start == null || !t.createdAt.isBefore(start)) &&
            (end == null || t.createdAt.isBefore(end)) &&
            (accountId.isEmpty ||
                t.accountId == accountId ||
                t.transferAccountId == accountId) &&
            (categoryId.isEmpty || t.categoryId == categoryId),
      )
      .toList();
  selected.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return selected;
}

Map<String, Object> activityTotals(List<MoneyTransaction> entries) => {
  'count': entries.length,
  'income': Money.sum(
    entries
        .where((t) => t.transactionType == TransactionType.income)
        .map((t) => t.amount),
  ),
  'expense': Money.sum(
    entries
        .where((t) => t.transactionType == TransactionType.expense)
        .map((t) => t.amount),
  ),
  'transfers': Money.sum(
    entries
        .where((t) => t.transactionType == TransactionType.transfer)
        .map((t) => t.amount),
  ),
};
