import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/filters/transaction_date_filter.dart';
import '../../../shared/formatters/currency_formatter.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/transaction_date_filter_bar.dart';
import '../../categories/data/categories_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/money_transaction.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  TransactionDateFilter _dateFilter = TransactionDateFilter.currentMonth();

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionsProvider).asData?.value ?? const [];
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';

    final filtered = filterTransactionsByDate(txs, _dateFilter);
    final income = filtered
        .where((t) => t.transactionType == TransactionType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = filtered
        .where((t) => t.transactionType == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    final byCategory = <String, double>{};
    for (final t in filtered.where(
      (t) => t.transactionType == TransactionType.expense,
    )) {
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
    }

    final pieSections = byCategory.entries.map((e) {
      final cat = categories.where((c) => c.id == e.key).firstOrNull;
      return PieChartSectionData(
        value: e.value,
        title: cat?.name ?? '?',
        color: Color(cat?.color ?? 0xFF607D8B),
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
      );
    }).toList();

    final trend = _buildTrend(filtered, _dateFilter);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TransactionDateFilterBar(
            value: _dateFilter,
            onChanged: (value) => setState(() => _dateFilter = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Income',
                  value: CurrencyFormatter.format(income, currency: currency),
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'Expense',
                  value: CurrencyFormatter.format(expense, currency: currency),
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatCard(
            label: 'Cash flow',
            value: CurrencyFormatter.format(
              income - expense,
              currency: currency,
            ),
            icon: Icons.waterfall_chart,
          ),
          const SectionHeader('Spending by category'),
          SizedBox(
            height: 220,
            child: pieSections.isEmpty
                ? const EmptyState(
                    icon: Icons.pie_chart,
                    title: 'No expense data',
                  )
                : PieChart(
                    PieChartData(
                      sections: pieSections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                    ),
                  ),
          ),
          const SectionHeader('Income vs expense trend'),
          SizedBox(
            height: 220,
            child: trend.isEmpty
                ? const EmptyState(
                    icon: Icons.show_chart,
                    title: 'Not enough data',
                  )
                : BarChart(
                    BarChartData(
                      barGroups: [
                        for (var i = 0; i < trend.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: trend[i].income,
                                color: Colors.green,
                                width: 8,
                              ),
                              BarChartRodData(
                                toY: trend[i].expense,
                                color: Colors.red,
                                width: 8,
                              ),
                            ],
                          ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= trend.length) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                trend[i].label,
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<_TrendPoint> _buildTrend(
    List<MoneyTransaction> txs,
    TransactionDateFilter filter,
  ) {
    final selectedRange = filter.range;
    final useHourlyBuckets = filter.preset == DateFilterPreset.day;
    final useMonthlyBuckets =
        filter.preset == DateFilterPreset.year ||
        selectedRange.duration.inDays > 31;
    final map = <DateTime, _TrendPoint>{};
    for (final t in txs) {
      final key = useHourlyBuckets
          ? DateTime(
              t.createdAt.year,
              t.createdAt.month,
              t.createdAt.day,
              t.createdAt.hour,
            )
          : useMonthlyBuckets
          ? DateTime(t.createdAt.year, t.createdAt.month)
          : DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      final point = map.putIfAbsent(
        key,
        () => _TrendPoint(
          label: useHourlyBuckets
              ? DateFormat.j().format(key)
              : useMonthlyBuckets
              ? DateFormat.MMM().format(key)
              : DateFormat.Md().format(key),
          income: 0,
          expense: 0,
        ),
      );
      if (t.transactionType == TransactionType.income) {
        point.income += t.amount;
      } else if (t.transactionType == TransactionType.expense) {
        point.expense += t.amount;
      }
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => entry.value).toList();
  }
}

class _TrendPoint {
  _TrendPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  double income;
  double expense;
}
