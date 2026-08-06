import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/transactions/domain/money_transaction.dart';

enum DateFilterPreset { day, month, year, custom }

class TransactionDateFilter {
  TransactionDateFilter({
    required this.preset,
    required DateTime anchor,
    this.customStart,
    this.customEnd,
  }) : anchor = _dateOnly(anchor);

  factory TransactionDateFilter.currentMonth([DateTime? now]) {
    return TransactionDateFilter(
      preset: DateFilterPreset.month,
      anchor: now ?? DateTime.now(),
    );
  }

  factory TransactionDateFilter.custom(DateTime start, DateTime end) {
    final normalizedStart = _dateOnly(start);
    final normalizedEnd = _dateOnly(end);
    return TransactionDateFilter(
      preset: DateFilterPreset.custom,
      anchor: normalizedStart,
      customStart: normalizedStart.isBefore(normalizedEnd)
          ? normalizedStart
          : normalizedEnd,
      customEnd: normalizedStart.isBefore(normalizedEnd)
          ? normalizedEnd
          : normalizedStart,
    );
  }

  final DateFilterPreset preset;
  final DateTime anchor;
  final DateTime? customStart;
  final DateTime? customEnd;

  DateTimeRange get range {
    switch (preset) {
      case DateFilterPreset.day:
        final start = _dateOnly(anchor);
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 1)),
        );
      case DateFilterPreset.month:
        final start = DateTime(anchor.year, anchor.month);
        return DateTimeRange(
          start: start,
          end: DateTime(anchor.year, anchor.month + 1),
        );
      case DateFilterPreset.year:
        final start = DateTime(anchor.year);
        return DateTimeRange(start: start, end: DateTime(anchor.year + 1));
      case DateFilterPreset.custom:
        final start = _dateOnly(customStart ?? anchor);
        final inclusiveEnd = _dateOnly(customEnd ?? customStart ?? anchor);
        return DateTimeRange(
          start: start,
          end: inclusiveEnd.add(const Duration(days: 1)),
        );
    }
  }

  bool matches(DateTime date) {
    final selectedRange = range;
    return !date.isBefore(selectedRange.start) &&
        date.isBefore(selectedRange.end);
  }

  TransactionDateFilter withPreset(DateFilterPreset nextPreset) {
    if (nextPreset == DateFilterPreset.custom) {
      return TransactionDateFilter.custom(anchor, anchor);
    }
    return TransactionDateFilter(preset: nextPreset, anchor: anchor);
  }

  TransactionDateFilter shift(int amount) {
    if (amount == 0 || preset == DateFilterPreset.custom) return this;
    final shifted = switch (preset) {
      DateFilterPreset.day => anchor.add(Duration(days: amount)),
      DateFilterPreset.month => DateTime(anchor.year, anchor.month + amount, 1),
      DateFilterPreset.year => DateTime(anchor.year + amount, 1, 1),
      DateFilterPreset.custom => anchor,
    };
    return TransactionDateFilter(preset: preset, anchor: shifted);
  }

  String get label {
    switch (preset) {
      case DateFilterPreset.day:
        return DateFormat.yMMMd().format(anchor);
      case DateFilterPreset.month:
        return DateFormat.yMMMM().format(anchor);
      case DateFilterPreset.year:
        return DateFormat.y().format(anchor);
      case DateFilterPreset.custom:
        final selectedRange = range;
        final inclusiveEnd = selectedRange.end.subtract(
          const Duration(days: 1),
        );
        if (selectedRange.start == inclusiveEnd) {
          return DateFormat.yMMMd().format(selectedRange.start);
        }
        return '${DateFormat.yMMMd().format(selectedRange.start)} – '
            '${DateFormat.yMMMd().format(inclusiveEnd)}';
    }
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

List<MoneyTransaction> filterTransactionsByDate(
  Iterable<MoneyTransaction> transactions,
  TransactionDateFilter filter,
) {
  return transactions.where((transaction) {
    return filter.matches(transaction.createdAt);
  }).toList();
}
