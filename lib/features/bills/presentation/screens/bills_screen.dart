import '../../../../core/l10n/app_text.dart';
import '../../../../shared/widgets/async_action_button.dart';
import '../../../accounts/data/accounts_repository.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/domain/category.dart';
import '../../domain/bill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/bills_repository.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Bills & subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: billsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('$e')),
        data: (bills) {
          if (bills.isEmpty) {
            return EmptyState(
              icon: Icons.event_note,
              title: 'No bills tracked',
              action: FilledButton(
                onPressed: () => _showForm(context, ref),
                child: const AppText('Add bill'),
              ),
            );
          }
          final sorted = [...bills]
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final b = sorted[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: b.paid
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      b.paid ? Icons.check : Icons.schedule,
                      color: b.paid ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(b.title),
                  subtitle: Text(
                    'Due ${DateFormat.yMMMd().format(b.dueDate)}${b.recurring ? ' · Monthly' : ''}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(b.amount, currency: currency),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      AsyncActionButton(
                        onPressed: b.paid ? null : () => _pay(context, ref, b),
                        child: Text(b.paid ? 'Paid' : 'Pay bill'),
                      ),
                    ],
                  ),
                  onLongPress: () => confirmMutation(
                    context,
                    title: 'Delete bill?',
                    action: () =>
                        ref.read(billsRepositoryProvider).delete(b.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, Bill bill) async {
    final accounts = (await ref.read(
      accountsProvider.future,
    )).where((a) => !a.archived).toList();
    final categories = (await ref.read(
      categoriesProvider.future,
    )).where((c) => c.type == CategoryType.expense).toList();
    if (!context.mounted) return;
    if (accounts.isEmpty || categories.isEmpty) {
      throw StateError('Add an account and expense category first.');
    }
    var account = accounts.first.id;
    var category = categories.first.id;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text('Pay ${bill.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Records an expense and updates the account balance.',
              ),
              DropdownButtonFormField<String>(
                initialValue: account,
                decoration: InputDecoration(
                  labelText: AppText.translate(context, 'Account'),
                ),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.accountName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setModal(() => account = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: AppText.translate(context, 'Category'),
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setModal(() => category = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Confirm payment'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await ref
          .read(billsRepositoryProvider)
          .markPaid(bill, accountId: account, categoryId: category);
    }
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final amount = TextEditingController();
    var due = DateTime.now().add(const Duration(days: 7));
    var recurring = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add bill', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: AppText.translate(context, 'Title'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    decoration: InputDecoration(
                      labelText: AppText.translate(context, 'Amount'),
                    ),
                    validator: Validators.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('Repeats monthly'),
                    value: recurring,
                    onChanged: (v) => setModal(() => recurring = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('Due date'),
                    subtitle: Text(DateFormat.yMMMd().format(due)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: due,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setModal(() => due = d);
                    },
                  ),
                  AsyncActionButton(
                    onPressed: () async {
                      final amt = double.tryParse(amount.text);
                      if (title.text.trim().isEmpty ||
                          amt == null ||
                          !amt.isFinite ||
                          amt <= 0) {
                        throw StateError(
                          'Enter a title and valid positive amount.',
                        );
                      }
                      await ref
                          .read(billsRepositoryProvider)
                          .create(
                            title: title.text.trim(),
                            amount: amt,
                            dueDate: due,
                            recurring: recurring,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const AppText('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
