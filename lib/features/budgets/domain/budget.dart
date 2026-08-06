import 'package:equatable/equatable.dart';

import '../../transactions/domain/money_transaction.dart';

enum BudgetPeriod { weekly, monthly }

class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.amount,
    required this.period,
    required this.monthKey,
    this.categoryIds = const [],
    this.spent = 0,
  });

  final String id;
  final List<String> categoryIds;
  final double amount;
  final BudgetPeriod period;
  final String monthKey;
  final double spent;

  double get remaining => amount - spent;
  bool get isExceeded => spent >= amount;
  double get progress => amount == 0 ? 0 : (spent / amount).clamp(0, 2);

  Budget copyWith({
    List<String>? categoryIds,
    double? amount,
    BudgetPeriod? period,
    String? monthKey,
    double? spent,
  }) {
    return Budget(
      id: id,
      categoryIds: categoryIds ?? this.categoryIds,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      monthKey: monthKey ?? this.monthKey,
      spent: spent ?? this.spent,
    );
  }

  /// Recomputes [spent] from live expense transactions for the budget period.
  Budget withLiveSpent(List<MoneyTransaction> transactions, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final start = period == BudgetPeriod.weekly
        ? DateTime(
            at.year,
            at.month,
            at.day,
          ).subtract(Duration(days: at.weekday - 1))
        : DateTime(at.year, at.month, 1);
    final end = period == BudgetPeriod.weekly
        ? start.add(const Duration(days: 7))
        : DateTime(at.year, at.month + 1, 1);

    var total = 0.0;
    for (final t in transactions) {
      if (t.transactionType != TransactionType.expense) continue;
      if (t.createdAt.isBefore(start) || !t.createdAt.isBefore(end)) continue;
      if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
        continue;
      }
      total += t.amount;
    }
    return copyWith(spent: total);
  }

  Map<String, dynamic> toMap() => {
    'categoryIds': categoryIds,
    // Kept during migration so older app versions can still read budgets
    // that target exactly one category.
    'categoryId': categoryIds.length == 1 ? categoryIds.first : null,
    'amount': amount,
    'period': period.name,
    'monthKey': monthKey,
    'spent': spent,
  };

  factory Budget.fromMap(String id, Map<String, dynamic> map) {
    final periodStr = map['period'] as String? ?? 'monthly';
    final storedCategoryIds =
        (map['categoryIds'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    final legacyCategoryId = map['categoryId'] as String?;
    return Budget(
      id: id,
      categoryIds: storedCategoryIds.isNotEmpty
          ? storedCategoryIds
          : legacyCategoryId == null || legacyCategoryId.isEmpty
          ? const []
          : [legacyCategoryId],
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      period: periodStr == 'weekly'
          ? BudgetPeriod.weekly
          : BudgetPeriod.monthly,
      monthKey: map['monthKey'] as String? ?? '',
      spent: (map['spent'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, categoryIds, amount, period, monthKey, spent];
}
