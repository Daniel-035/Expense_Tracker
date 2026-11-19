import '../../../core/utils/money.dart';
import 'package:equatable/equatable.dart';

class Bill extends Equatable {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.recurring = true,
    this.paid = false,
    this.billingDay,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool recurring;
  final bool paid;
  final int? billingDay;

  Map<String, dynamic> toMap() => {
    'title': title,
    'amount': amount,
    'amountMinor': Money.minor(amount),
    'dueDate': dueDate.toIso8601String(),
    'recurring': recurring,
    'paid': paid,
    'billingDay': billingDay ?? dueDate.day,
  };

  factory Bill.fromMap(String id, Map<String, dynamic> map) {
    return Bill(
      id: id,
      title: map['title'] as String? ?? '',
      amount: Money.read(map, 'amount'),
      dueDate:
          DateTime.tryParse(map['dueDate'] as String? ?? '') ?? DateTime.now(),
      recurring: map['recurring'] as bool? ?? true,
      paid: map['paid'] as bool? ?? false,
      billingDay: map['billingDay'] as int?,
    );
  }

  Bill copyWith({bool? paid, DateTime? dueDate}) {
    return Bill(
      id: id,
      title: title,
      amount: amount,
      dueDate: dueDate ?? this.dueDate,
      recurring: recurring,
      paid: paid ?? this.paid,
      billingDay: billingDay ?? this.dueDate.day,
    );
  }

  @override
  List<Object?> get props => [id, title, amount, dueDate, recurring, paid];
}
