import 'package:intl/intl.dart';
import '../../../../shared/widgets/async_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/budgets_repository.dart';
import '../../domain/budget.dart';

final _budgetDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = ref.watch(_budgetDateProvider);
    final budgetsAsync = ref.watch(budgetsForDateProvider(at));
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.budgetsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: TextButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(
              'Recurring limits - ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(at)}',
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: at,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ref.read(_budgetDateProvider.notifier).state = picked;
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: budgetsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('$e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return EmptyState(
              icon: Icons.pie_chart,
              title: l10n.noBudgets,
              subtitle: l10n.noBudgetsHint,
              action: FilledButton(
                onPressed: () => _showForm(context, ref),
                child: Text(l10n.createBudget),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.liveFromActivity,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final b = budgets[i - 1];
              final selectedCategoryNames = categories
                  .where((category) => b.categoryIds.contains(category.id))
                  .map((category) => category.name)
                  .toList();
              final catName = b.categoryIds.isEmpty
                  ? l10n.overall
                  : selectedCategoryNames.isEmpty
                  ? l10n.navCategories
                  : selectedCategoryNames.join(', ');
              final periodLabel = b.period == BudgetPeriod.weekly
                  ? l10n.weekly
                  : l10n.monthly;
              final color = b.isExceeded
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$catName · $periodLabel',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => confirmMutation(
                              context,
                              title: 'Delete budget?',
                              action: () => ref
                                  .read(budgetsRepositoryProvider)
                                  .delete(b.id),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${CurrencyFormatter.format(b.spent, currency: currency)} / ${CurrencyFormatter.format(b.amount, currency: currency)}',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: b.progress.clamp(0, 1),
                        color: color,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.isExceeded
                            ? l10n.exceeded
                            : '${l10n.remaining} ${CurrencyFormatter.format(b.remaining, currency: currency)}',
                        style: TextStyle(
                          color: b.isExceeded ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    var period = BudgetPeriod.monthly;
    final selectedCategoryIds = <String>{};
    final categories = ref.read(categoriesProvider).asData?.value ?? [];
    final expenseCats = categories
        .where((c) => c.type.name == 'expense')
        .toList();
    final l10n = ref.read(l10nProvider);

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
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.newBudget,
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amount,
                      decoration: InputDecoration(labelText: l10n.limit),
                      validator: Validators.amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BudgetPeriod>(
                      // ignore: deprecated_member_use
                      value: period,
                      decoration: InputDecoration(labelText: l10n.period),
                      items: [
                        DropdownMenuItem(
                          value: BudgetPeriod.weekly,
                          child: Text(l10n.weekly),
                        ),
                        DropdownMenuItem(
                          value: BudgetPeriod.monthly,
                          child: Text(l10n.monthly),
                        ),
                      ],
                      onChanged: (v) => setModal(() => period = v!),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.categoryOptional,
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedCategoryIds.isEmpty
                          ? '${l10n.overall} — all expense categories'
                          : 'Expenses from ${selectedCategoryIds.length} selected '
                                '${selectedCategoryIds.length == 1 ? 'category' : 'categories'} will count toward this budget.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final category in expenseCats)
                          FilterChip(
                            label: Text(category.name),
                            selected: selectedCategoryIds.contains(category.id),
                            onSelected: (selected) {
                              setModal(() {
                                if (selected) {
                                  selectedCategoryIds.add(category.id);
                                } else {
                                  selectedCategoryIds.remove(category.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AsyncActionButton(
                      onPressed: () async {
                        final amt = double.tryParse(amount.text);
                        if (amt == null || !amt.isFinite || amt <= 0) {
                          throw StateError('Enter a valid positive amount.');
                        }
                        await ref
                            .read(budgetsRepositoryProvider)
                            .create(
                              amount: amt,
                              period: period,
                              categoryIds: selectedCategoryIds.toList(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
