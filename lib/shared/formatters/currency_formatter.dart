import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(
    num amount, {
    String currency = 'INR',
    String locale = 'en_IN',
  }) {
    return NumberFormat.currency(
      locale: locale,
      symbol: _symbol(currency),
      decimalDigits: 2,
    ).format(amount);
  }

  static String _symbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
      default:
        return '₹';
    }
  }
}
