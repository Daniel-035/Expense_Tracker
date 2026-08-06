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
  });

  final String id;
  final String accountName;
  final AccountType accountType;
  final double balance;

  Account copyWith({
    String? accountName,
    AccountType? accountType,
    double? balance,
  }) {
    return Account(
      id: id,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toMap() => {
        'accountName': accountName,
        'accountType': accountType.name,
        'balance': balance,
      };

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    return Account(
      id: id,
      accountName: map['accountName'] as String? ?? '',
      accountType: AccountType.fromString(map['accountType'] as String? ?? 'cash'),
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, accountName, accountType, balance];
}
