/// Two-decimal ledger currency. Persist minor units; retain legacy decimal
/// fields during migration so existing records remain readable.
class Money {
  static const maxMinor = 9000000000000;

  static int minor(double value, {bool positive = false}) {
    if (!value.isFinite || value.abs() > maxMinor / 100) {
      throw StateError('Enter a finite amount within the supported range.');
    }
    final result = (value * 100).round();
    if ((result / 100 - value).abs() > 0.0000001 || (positive && result <= 0)) {
      throw StateError(
        'Use a positive amount with at most two decimal places.',
      );
    }
    return result;
  }

  static double read(Map<String, dynamic> data, String field) =>
      data['${field}Minor'] is int
      ? (data['${field}Minor'] as int) / 100
      : (data[field] as num?)?.toDouble() ?? 0;

  static double add(double left, double right) =>
      (minor(left) + minor(right)) / 100;

  static double sum(Iterable<double> amounts) =>
      amounts.fold<int>(0, (total, amount) => total + minor(amount)) / 100;

  static void name(String value) {
    if (value.trim().isEmpty || value.length > 120) {
      throw StateError('Enter a name between 1 and 120 characters.');
    }
  }
}
