import '../../../core/l10n/app_text.dart';
import '../../../shared/widgets/data_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/formatters/currency_formatter.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../bills/data/bills_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/money_transaction.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final status = dataStatus(
      [ref.watch(transactionsProvider), ref.watch(billsProvider)],
      () {
        ref.invalidate(transactionsProvider);
        ref.invalidate(billsProvider);
      },
    );
    if (status != null) return status;
    final txs = ref.watch(transactionsProvider).asData?.value ?? const [];
    final bills = ref.watch(billsProvider).asData?.value ?? const [];
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';

    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final firstWeekday = DateTime(_focused.year, _focused.month, 1).weekday;

    final dayTx = txs.where(
      (t) =>
          t.createdAt.year == _selected.year &&
          t.createdAt.month == _selected.month &&
          t.createdAt.day == _selected.day,
    );
    final dayBills = bills.where(
      (b) =>
          b.dueDate.year == _selected.year &&
          b.dueDate.month == _selected.month &&
          b.dueDate.day == _selected.day,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMM().format(_focused)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _focused = DateTime(_focused.year, _focused.month - 1);
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _focused = DateTime(_focused.year, _focused.month + 1);
            }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              Expanded(child: Center(child: AppText('Mon'))),
              Expanded(child: Center(child: AppText('Tue'))),
              Expanded(child: Center(child: AppText('Wed'))),
              Expanded(child: Center(child: AppText('Thu'))),
              Expanded(child: Center(child: AppText('Fri'))),
              Expanded(child: Center(child: AppText('Sat'))),
              Expanded(child: Center(child: AppText('Sun'))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: firstWeekday - 1 + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink();
              }
              final day = index - (firstWeekday - 1) + 1;
              final date = DateTime(_focused.year, _focused.month, day);
              final hasTx = txs.any(
                (t) =>
                    t.createdAt.year == date.year &&
                    t.createdAt.month == date.month &&
                    t.createdAt.day == date.day,
              );
              final hasBill = bills.any(
                (b) =>
                    b.dueDate.year == date.year &&
                    b.dueDate.month == date.month &&
                    b.dueDate.day == date.day,
              );
              final selected =
                  _selected.year == date.year &&
                  _selected.month == date.month &&
                  _selected.day == date.day;
              return InkWell(
                onTap: () => setState(() => _selected = date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasTx)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasBill) ...[
                            const SizedBox(width: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SectionHeader(DateFormat.yMMMEd().format(_selected)),
          if (dayTx.isEmpty && dayBills.isEmpty)
            const AppText('Nothing on this day')
          else ...[
            ...dayTx.map((t) {
              final isIncome = t.transactionType == TransactionType.income;
              return ListTile(
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                ),
                title: Text(t.merchant ?? t.transactionType.name),
                trailing: Text(
                  CurrencyFormatter.format(t.amount, currency: currency),
                ),
              );
            }),
            ...dayBills.map(
              (b) => ListTile(
                leading: const Icon(Icons.event_note, color: Colors.orange),
                title: Text(b.title),
                trailing: Text(
                  CurrencyFormatter.format(b.amount, currency: currency),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
