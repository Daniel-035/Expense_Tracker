import '../../features/transactions/domain/money_transaction.dart';

DateTime nextOccurrence(
  DateTime from,
  RecurrenceInterval interval, {
  int? anchorDay,
}) {
  final day = anchorDay ?? from.day;
  switch (interval) {
    case RecurrenceInterval.daily:
      return DateTime(
        from.year,
        from.month,
        from.day + 1,
        from.hour,
        from.minute,
      );
    case RecurrenceInterval.weekly:
      return DateTime(
        from.year,
        from.month,
        from.day + 7,
        from.hour,
        from.minute,
      );
    case RecurrenceInterval.monthly:
    case RecurrenceInterval.yearly:
      final month = interval == RecurrenceInterval.monthly
          ? from.month + 1
          : from.month;
      final year = interval == RecurrenceInterval.yearly
          ? from.year + 1
          : from.year;
      final last = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, day.clamp(1, last), from.hour, from.minute);
    case RecurrenceInterval.none:
      return from;
  }
}
