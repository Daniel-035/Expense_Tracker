import '../../../core/l10n/app_text.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/data_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/formatters/currency_formatter.dart';
import '../../../shared/widgets/animated_widgets.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../bills/data/bills_repository.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/money_transaction.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = dataStatus(
      [
        ref.watch(accountsProvider),
        ref.watch(transactionsProvider),
        ref.watch(liveBudgetsProvider),
        ref.watch(billsProvider),
        ref.watch(goalsProvider),
      ],
      () {
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(liveBudgetsProvider);
        ref.invalidate(billsProvider);
        ref.invalidate(goalsProvider);
      },
    );
    if (status != null) return status;
    final profile = ref.watch(authStateProvider).asData?.value;
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    final txs = ref.watch(transactionsProvider).asData?.value ?? const [];
    final budgets = ref.watch(liveBudgetsProvider).asData?.value ?? const [];
    final bills = ref.watch(billsProvider).asData?.value ?? const [];
    final goals = ref.watch(goalsProvider).asData?.value ?? const [];
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';

    final now = DateTime.now();
    final balance = accounts.fold<double>(0, (s, a) => Money.add(s, a.balance));
    final monthTx = txs.where(
      (t) => t.createdAt.year == now.year && t.createdAt.month == now.month,
    );
    final income = monthTx
        .where((t) => t.transactionType == TransactionType.income)
        .fold<double>(0, (s, t) => Money.add(s, t.amount));
    final expense = monthTx
        .where((t) => t.transactionType == TransactionType.expense)
        .fold<double>(0, (s, t) => Money.add(s, t.amount));
    final savings = goals.fold<double>(
      0,
      (s, g) => Money.add(s, g.savedAmount),
    );
    final upcoming = bills.where((b) => !b.paid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final recent = txs.take(5).toList();
    final budgetProgress = budgets.isEmpty
        ? 0.0
        : budgets.map((b) => b.progress).reduce((a, b) => a + b) /
              budgets.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('Dashboard'),
            Text(
              'Hello, ${profile?.name.split(' ').first ?? 'there'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.azure,
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          await Future.wait([
            ref.read(accountsProvider.future),
            ref.read(transactionsProvider.future),
          ]);
        },
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          cacheExtent: 400,
          children: [
            HeroBalanceCard(
              label: 'Current balance',
              value: CurrencyFormatter.format(balance, currency: currency),
              subtitle:
                  ref.watch(transactionSyncProvider).asData?.value ??
                  'Checking data status...',
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Monthly income',
                      value: CurrencyFormatter.format(
                        income,
                        currency: currency,
                      ),
                      icon: Icons.south_west_rounded,
                      color: AppColors.income,
                      onTap: () => context.go('/transactions'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Monthly expense',
                      value: CurrencyFormatter.format(
                        expense,
                        currency: currency,
                      ),
                      icon: Icons.north_east_rounded,
                      color: AppColors.expense,
                      onTap: () => context.go('/transactions'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Goal progress',
                      value: CurrencyFormatter.format(
                        savings,
                        currency: currency,
                      ),
                      icon: Icons.savings_outlined,
                      color: AppColors.sky,
                      onTap: () => context.go('/goals'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TapScale(
                      onTap: () => context.go('/budgets'),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Budget usage',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.slate,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: budgetProgress.clamp(0, 1),
                                ),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 9,
                                    borderRadius: BorderRadius.circular(8),
                                    color: AppColors.azure,
                                    backgroundColor: AppColors.azure.withValues(
                                      alpha: 0.12,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(budgetProgress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 110),
              child: TapScale(
                onTap: () => context.go('/ai'),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.azure.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.azure,
                      ),
                    ),
                    title: const Text(
                      'AI Chat',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      expense > income
                          ? 'Expenses exceed income this month. Review discretionary spending.'
                          : income == 0 && expense == 0
                          ? 'Log your first transaction to unlock insights.'
                          : 'You are ${CurrencyFormatter.format(income - expense, currency: currency)} ahead this month. Keep it up!',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ),
            SectionHeader(
              'Recent transactions',
              trailing: TextButton(
                onPressed: () => context.go('/transactions'),
                child: const AppText('See all'),
              ),
            ),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long,
                title: 'No transactions yet',
                subtitle: 'Tap + to add income or expense',
              )
            else
              ...List.generate(recent.length, (i) {
                final t = recent[i];
                final isIncome = t.transactionType == TransactionType.income;
                return FadeSlideIn(
                  delay: Duration(milliseconds: 60 + i * 40),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TapScale(
                      onTap: () => context.push('/transactions/${t.id}'),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome
                                ? AppColors.income.withValues(alpha: 0.12)
                                : AppColors.expense.withValues(alpha: 0.12),
                            child: Icon(
                              isIncome
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              color: isIncome
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          title: Text(
                            t.merchant?.isNotEmpty == true
                                ? t.merchant!
                                : t.notes?.isNotEmpty == true
                                ? t.notes!
                                : t.transactionType.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            DateFormat.yMMMd().format(t.createdAt),
                          ),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}${CurrencyFormatter.format(t.amount, currency: currency)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isIncome
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            SectionHeader(
              'Upcoming bills',
              trailing: TextButton(
                onPressed: () => context.go('/bills'),
                child: const AppText('Manage'),
              ),
            ),
            if (upcoming.isEmpty)
              Text(
                'No upcoming bills',
                style: TextStyle(color: AppColors.slate),
              )
            else
              ...upcoming
                  .take(3)
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TapScale(
                        onTap: () => context.go('/bills'),
                        child: Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFF7ED),
                              child: Icon(
                                Icons.event_note,
                                color: AppColors.warning,
                              ),
                            ),
                            title: Text(
                              b.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Due ${DateFormat.yMMMd().format(b.dueDate)}',
                            ),
                            trailing: Text(
                              CurrencyFormatter.format(
                                b.amount,
                                currency: currency,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
