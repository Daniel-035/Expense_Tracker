import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/filters/transaction_date_filter.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/transaction_date_filter_bar.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/transactions_repository.dart';
import '../../domain/money_transaction.dart';
import '../../../../core/utils/export_actions.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _typeFilterProvider = StateProvider<TransactionType?>((ref) => null);
final _dateFilterProvider = StateProvider<TransactionDateFilter>(
  (ref) => TransactionDateFilter.currentMonth(),
);

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';
    final query = ref.watch(_searchQueryProvider).toLowerCase();
    final typeFilter = ref.watch(_typeFilterProvider);
    final dateFilter = ref.watch(_dateFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Export / share',
            onPressed: () => showExportShareSheet(context, ref),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search merchant, notes, amount…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  ref.read(_searchQueryProvider.notifier).state = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TransactionDateFilterBar(
              value: dateFilter,
              onChanged: (value) {
                ref.read(_dateFilterProvider.notifier).state = value;
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: typeFilter == null,
                  onSelected: (_) =>
                      ref.read(_typeFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Income'),
                  selected: typeFilter == TransactionType.income,
                  onSelected: (_) =>
                      ref.read(_typeFilterProvider.notifier).state =
                          TransactionType.income,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expense'),
                  selected: typeFilter == TransactionType.expense,
                  onSelected: (_) =>
                      ref.read(_typeFilterProvider.notifier).state =
                          TransactionType.expense,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Transfer'),
                  selected: typeFilter == TransactionType.transfer,
                  onSelected: (_) =>
                      ref.read(_typeFilterProvider.notifier).state =
                          TransactionType.transfer,
                ),
              ],
            ),
          ),
          Expanded(
            child: txsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => Center(child: Text('$e')),
              data: (txs) {
                final filtered = txs.where((t) {
                  if (!dateFilter.matches(t.createdAt)) {
                    return false;
                  }
                  if (typeFilter != null && t.transactionType != typeFilter) {
                    return false;
                  }
                  if (query.isEmpty) return true;
                  final hay = [
                    t.merchant,
                    t.notes,
                    t.amount.toString(),
                    ...t.tags,
                  ].whereType<String>().join(' ').toLowerCase();
                  return hay.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long,
                    title: 'No matching transactions',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final cat = categories
                        .where((c) => c.id == t.categoryId)
                        .firstOrNull;
                    final isIncome =
                        t.transactionType == TransactionType.income;
                    final isTransfer =
                        t.transactionType == TransactionType.transfer;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            (cat?.color ?? 0xFF607D8B),
                          ).withValues(alpha: 0.2),
                          child: Icon(
                            isTransfer
                                ? Icons.swap_horiz
                                : isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isTransfer
                                ? Theme.of(context).colorScheme.primary
                                : isIncome
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: Text(
                          t.merchant?.isNotEmpty == true
                              ? t.merchant!
                              : (cat?.name ?? t.transactionType.name),
                        ),
                        subtitle: Text(
                          '${cat?.name ?? '—'} · ${DateFormat.yMMMd().add_jm().format(t.createdAt)}',
                        ),
                        trailing: Text(
                          '${isTransfer
                              ? ''
                              : isIncome
                              ? '+'
                              : '-'}'
                          '${CurrencyFormatter.format(t.amount, currency: currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isTransfer
                                ? Theme.of(context).colorScheme.primary
                                : isIncome
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        onTap: () {
                          if (isTransfer) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Transfers are managed from Accounts.',
                                ),
                              ),
                            );
                            return;
                          }
                          context.push('/transactions/${t.id}');
                        },
                        onLongPress: () async {
                          final action = await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.copy),
                                    title: const Text('Duplicate'),
                                    onTap: () => Navigator.pop(ctx, 'dup'),
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.delete,
                                      color: Theme.of(ctx).colorScheme.error,
                                    ),
                                    title: const Text('Delete'),
                                    onTap: () => Navigator.pop(ctx, 'del'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (action == 'dup') {
                            await ref
                                .read(transactionsRepositoryProvider)
                                .duplicate(t);
                          } else if (action == 'del') {
                            await ref
                                .read(transactionsRepositoryProvider)
                                .delete(t.id);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
