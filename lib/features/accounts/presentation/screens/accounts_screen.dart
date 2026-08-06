import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/formatters/currency_formatter.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/accounts_repository.dart';
import '../../domain/account.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer',
            onPressed: () => _showTransfer(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('$e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet,
              title: 'No accounts',
              action: FilledButton(
                onPressed: () => _showForm(context, ref),
                child: const Text('Add account'),
              ),
            );
          }
          final total =
              accounts.fold<double>(0, (s, a) => s + a.balance);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatCard(
                label: 'Total balance',
                value: CurrencyFormatter.format(total, currency: currency),
                icon: Icons.account_balance,
              ),
              const SizedBox(height: 12),
              ...accounts.map(
                (a) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_iconFor(a.accountType)),
                    ),
                    title: Text(a.accountName),
                    subtitle: Text(a.accountType.label),
                    trailing: Text(
                      CurrencyFormatter.format(a.balance, currency: currency),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _showForm(context, ref, account: a),
                    onLongPress: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete account?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref
                            .read(accountsRepositoryProvider)
                            .delete(a.id);
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.upi:
        return Icons.qr_code;
      case AccountType.wallet:
        return Icons.account_balance_wallet;
      case AccountType.savings:
        return Icons.savings;
      case AccountType.investment:
        return Icons.trending_up;
    }
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    Account? account,
  }) async {
    final name = TextEditingController(text: account?.accountName);
    final balance = TextEditingController(
      text: account == null ? '0' : account.balance.toString(),
    );
    var type = account?.accountType ?? AccountType.cash;

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
                  Text(
                    account == null ? 'Add account' : 'Edit account',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccountType>(
                    // ignore: deprecated_member_use
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: AccountType.values
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.label),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balance,
                    decoration:
                        const InputDecoration(labelText: 'Opening balance'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final bal = double.tryParse(balance.text) ?? 0;
                      if (account == null) {
                        await ref.read(accountsRepositoryProvider).create(
                              name: name.text.trim(),
                              type: type,
                              balance: bal,
                            );
                      } else {
                        await ref.read(accountsRepositoryProvider).update(
                              account.copyWith(
                                accountName: name.text.trim(),
                                accountType: type,
                                balance: bal,
                              ),
                            );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showTransfer(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsProvider).asData?.value ?? [];
    if (accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least two accounts')),
      );
      return;
    }
    String? from = accounts[0].id;
    String? to = accounts[1].id;
    final amount = TextEditingController();

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
                  Text('Transfer', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: from,
                    decoration: const InputDecoration(labelText: 'From'),
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.accountName),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => from = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: to,
                    decoration: const InputDecoration(labelText: 'To'),
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.accountName),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => to = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: Validators.amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (from == null || to == null || from == to) return;
                      final amt = double.tryParse(amount.text);
                      if (amt == null || amt <= 0) return;
                      await ref.read(accountsRepositoryProvider).transfer(
                            fromId: from!,
                            toId: to!,
                            amount: amt,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Transfer'),
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
