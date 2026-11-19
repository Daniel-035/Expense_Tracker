import '../../../../core/l10n/app_text.dart';
import '../../../../shared/widgets/async_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/goals_repository.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Savings progress'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(36),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Tracks progress only; entries do not move account funds.',
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreate(context, ref),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('$e')),
        data: (goals) {
          if (goals.isEmpty) {
            return EmptyState(
              icon: Icons.flag,
              title: 'No goals yet',
              subtitle: 'Emergency fund, vacation, house…',
              action: FilledButton(
                onPressed: () => _showCreate(context, ref),
                child: const AppText('Create goal'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, i) {
              final g = goals[i];
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
                              g.goalName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (g.isComplete)
                            const Chip(label: AppText('Complete')),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                ref.read(goalsRepositoryProvider).delete(g.id),
                          ),
                        ],
                      ),
                      Text(
                        '${CurrencyFormatter.format(g.savedAmount, currency: currency)} of ${CurrencyFormatter.format(g.targetAmount, currency: currency)}',
                      ),
                      Text(
                        'Target ${DateFormat.yMMMd().format(g.deadline)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: g.progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () => _showDeposit(context, ref, g.id),
                          child: const AppText('Record progress'),
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

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final target = TextEditingController();
    var deadline = DateTime.now().add(const Duration(days: 90));

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
                  Text('New goal', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: AppText.translate(context, 'Name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: target,
                    decoration: const InputDecoration(
                      labelText: 'Target amount',
                    ),
                    validator: Validators.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('Deadline'),
                    subtitle: Text(DateFormat.yMMMd().format(deadline)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setModal(() => deadline = d);
                    },
                  ),
                  AsyncActionButton(
                    onPressed: () async {
                      final amt = double.tryParse(target.text);
                      if (name.text.trim().isEmpty || amt == null) return;
                      await ref
                          .read(goalsRepositoryProvider)
                          .create(
                            name: name.text.trim(),
                            target: amt,
                            deadline: deadline,
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

  Future<void> _showDeposit(
    BuildContext context,
    WidgetRef ref,
    String goalId,
  ) async {
    final amount = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Deposit'),
        content: TextField(
          controller: amount,
          decoration: InputDecoration(
            labelText: AppText.translate(context, 'Amount'),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Cancel'),
          ),
          AsyncActionButton(
            onPressed: () async {
              final amt = double.tryParse(amount.text);
              if (amt == null || !amt.isFinite || amt <= 0) {
                throw StateError('Enter a valid positive amount.');
              }
              await ref
                  .read(goalsRepositoryProvider)
                  .deposit(goalId: goalId, amount: amt);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const AppText('Add'),
          ),
        ],
      ),
    );
  }
}
