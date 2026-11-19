import '../../../core/utils/money.dart';
import 'package:equatable/equatable.dart';

enum TransactionType { income, expense, transfer }

enum RecurrenceInterval { none, daily, weekly, monthly, yearly }

class MoneyTransaction extends Equatable {
  static const _unset = Object();
  const MoneyTransaction({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.transactionType,
    required this.createdAt,
    this.merchant,
    this.notes,
    this.receiptUrl,
    this.location,
    this.tags = const [],
    this.transferAccountId,
    this.recurrence = RecurrenceInterval.none,
    this.nextOccurrence,
  });

  final String id;
  final String accountId;
  final String categoryId;
  final double amount;
  final TransactionType transactionType;
  final String? merchant;
  final String? notes;
  final String? receiptUrl;
  final String? location;
  final List<String> tags;
  final String? transferAccountId;
  final RecurrenceInterval recurrence;
  final DateTime? nextOccurrence;
  final DateTime createdAt;

  MoneyTransaction copyWith({
    String? id,
    String? accountId,
    String? categoryId,
    double? amount,
    TransactionType? transactionType,
    Object? merchant = _unset,
    Object? notes = _unset,
    Object? receiptUrl = _unset,
    Object? location = _unset,
    List<String>? tags,
    Object? transferAccountId = _unset,
    RecurrenceInterval? recurrence,
    Object? nextOccurrence = _unset,
    DateTime? createdAt,
  }) {
    return MoneyTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      merchant: identical(merchant, _unset)
          ? this.merchant
          : merchant as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      receiptUrl: identical(receiptUrl, _unset)
          ? this.receiptUrl
          : receiptUrl as String?,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      tags: tags ?? this.tags,
      transferAccountId: identical(transferAccountId, _unset)
          ? this.transferAccountId
          : transferAccountId as String?,
      recurrence: recurrence ?? this.recurrence,
      nextOccurrence: identical(nextOccurrence, _unset)
          ? this.nextOccurrence
          : nextOccurrence as DateTime?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'categoryId': categoryId,
    'amount': amount,
    'amountMinor': Money.minor(amount),
    'transactionType': transactionType.name,
    'merchant': merchant,
    'notes': notes,
    'receiptUrl': receiptUrl,
    'location': location,
    'tags': tags,
    'transferAccountId': transferAccountId,
    'recurrence': recurrence.name,
    'nextOccurrence': nextOccurrence?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory MoneyTransaction.fromMap(String id, Map<String, dynamic> map) {
    final typeStr = map['transactionType'] as String? ?? 'expense';
    final recurrenceStr = map['recurrence'] as String? ?? 'none';
    return MoneyTransaction(
      id: id,
      accountId: map['accountId'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      amount: Money.read(map, 'amount'),
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => TransactionType.expense,
      ),
      merchant: map['merchant'] as String?,
      notes: map['notes'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
      location: map['location'] as String?,
      tags:
          (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      transferAccountId: map['transferAccountId'] as String?,
      recurrence: RecurrenceInterval.values.firstWhere(
        (e) => e.name == recurrenceStr,
        orElse: () => RecurrenceInterval.none,
      ),
      nextOccurrence: DateTime.tryParse(map['nextOccurrence'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    accountId,
    categoryId,
    amount,
    transactionType,
    merchant,
    notes,
    createdAt,
    receiptUrl,
    location,
    tags,
    transferAccountId,
    recurrence,
    nextOccurrence,
  ];
}
