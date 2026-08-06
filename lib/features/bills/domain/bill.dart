import 'package:equatable/equatable.dart';

class Bill extends Equatable {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.recurring = true,
    this.paid = false,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool recurring;
  final bool paid;

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'recurring': recurring,
        'paid': paid,
      };

  factory Bill.fromMap(String id, Map<String, dynamic> map) {
    return Bill(
      id: id,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dueDate:
          DateTime.tryParse(map['dueDate'] as String? ?? '') ?? DateTime.now(),
      recurring: map['recurring'] as bool? ?? true,
      paid: map['paid'] as bool? ?? false,
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
    );
  }

  @override
  List<Object?> get props => [id, title, amount, dueDate, recurring, paid];
}
