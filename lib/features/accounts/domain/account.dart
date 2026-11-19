import '../../../core/utils/money.dart';
import 'package:equatable/equatable.dart';

enum AccountType {
  cash,
  bank,
  creditCard,
  upi,
  wallet,
  savings,
  investment;

  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.upi:
        return 'UPI';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.savings:
        return 'Savings';
      case AccountType.investment:
        return 'Investment';
    }
  }

  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountType.cash,
    );
  }
}

class Account extends Equatable {
  const Account({
    required this.id,
    required this.accountName,
    required this.accountType,
    required this.balance,
    this.archived = false,
  });

  final String id;
  final String accountName;
  final AccountType accountType;
  final double balance;
  final bool archived;

  Account copyWith({
    String? accountName,
    AccountType? accountType,
    double? balance,
    bool? archived,
  }) {
    return Account(
      id: id,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      balance: balance ?? this.balance,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toMap() => {
    'accountName': accountName,
    'accountType': accountType.name,
    'balance': balance,
    'archived': archived,
    'balanceMinor': Money.minor(balance),
  };

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    return Account(
      id: id,
      accountName: map['accountName'] as String? ?? '',
      accountType: AccountType.fromString(
        map['accountType'] as String? ?? 'cash',
      ),
      balance: Money.read(map, 'balance'),
      archived: map['archived'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, accountName, accountType, balance, archived];
}
