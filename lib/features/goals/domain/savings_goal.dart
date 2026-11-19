import '../../../core/utils/money.dart';
import 'package:equatable/equatable.dart';

class SavingsGoal extends Equatable {
  const SavingsGoal({
    required this.id,
    required this.goalName,
    required this.targetAmount,
    required this.savedAmount,
    required this.deadline,
  });

  final String id;
  final String goalName;
  final double targetAmount;
  final double savedAmount;
  final DateTime deadline;

  double get progress =>
      targetAmount == 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);
  bool get isComplete => savedAmount >= targetAmount;

  Map<String, dynamic> toMap() => {
    'goalName': goalName,
    'targetAmount': targetAmount,
    'targetAmountMinor': Money.minor(targetAmount),
    'savedAmount': savedAmount,
    'savedAmountMinor': Money.minor(savedAmount),
    'deadline': deadline.toIso8601String(),
  };

  factory SavingsGoal.fromMap(String id, Map<String, dynamic> map) {
    return SavingsGoal(
      id: id,
      goalName: map['goalName'] as String? ?? '',
      targetAmount: Money.read(map, 'targetAmount'),
      savedAmount: Money.read(map, 'savedAmount'),
      deadline:
          DateTime.tryParse(map['deadline'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
    );
  }

  @override
  List<Object?> get props => [
    id,
    goalName,
    targetAmount,
    savedAmount,
    deadline,
  ];
}

class GoalDeposit extends Equatable {
  const GoalDeposit({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.note,
  });

  final String id;
  final double amount;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'amountMinor': Money.minor(amount),
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };

  factory GoalDeposit.fromMap(String id, Map<String, dynamic> map) {
    return GoalDeposit(
      id: id,
      amount: Money.read(map, 'amount'),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      note: map['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, amount, createdAt, note];
}
