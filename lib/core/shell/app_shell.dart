import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_l10n.dart';
import '../theme/app_colors.dart';
import '../theme/bluish_backdrop.dart';
import '../../shared/widgets/animated_widgets.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexFor(String location, List<_NavItem> items) {
    final i = items.indexWhere((e) => location.startsWith(e.path));
    return i < 0 ? (items.length == 5 ? 4 : 0) : i;
  }

  List<_NavItem> _mobile(AppL10n l10n) => [
    _NavItem(
      '/dashboard',
      l10n.navHome,
      Icons.dashboard_outlined,
      Icons.dashboard,
    ),
    _NavItem(
      '/transactions',
      l10n.navActivity,
      Icons.receipt_long_outlined,
      Icons.receipt_long,
    ),
    _NavItem(
      '/accounts',
      l10n.navAccounts,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
    _NavItem(
      '/budgets',
      l10n.navBudgets,
      Icons.pie_chart_outline,
      Icons.pie_chart,
    ),
    _NavItem('/profile', l10n.navMore, Icons.menu, Icons.menu_open),
  ];

  List<_NavItem> _sidebar(AppL10n l10n) => [
    _NavItem(
      '/dashboard',
      l10n.navDashboard,
      Icons.dashboard_outlined,
      Icons.dashboard,
    ),
    _NavItem(
      '/transactions',
      l10n.navTransactions,
      Icons.receipt_long_outlined,
      Icons.receipt_long,
    ),
    _NavItem(
      '/accounts',
      l10n.navAccounts,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
    _NavItem(
      '/categories',
      l10n.navCategories,
      Icons.category_outlined,
      Icons.category,
    ),
    _NavItem(
      '/budgets',
      l10n.navBudgets,
      Icons.pie_chart_outline,
      Icons.pie_chart,
    ),
    _NavItem(
      '/bills',
      l10n.navBills,
      Icons.event_note_outlined,
      Icons.event_note,
    ),
    _NavItem('/goals', l10n.navGoals, Icons.flag_outlined, Icons.flag),
    _NavItem(
      '/analytics',
      l10n.navAnalytics,
      Icons.insights_outlined,
      Icons.insights,
    ),
    _NavItem(
      '/calendar',
      l10n.navCalendar,
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
    _NavItem('/ai', l10n.navChat, Icons.chat_bubble_outline, Icons.chat_bubble),
    _NavItem('/profile', l10n.navProfile, Icons.person_outline, Icons.person),
    _NavItem(
      '/settings',
      l10n.navSettings,
      Icons.settings_outlined,
      Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final l10n = ref.watch(l10nProvider);
    final mobileDestinations = _mobile(l10n);
    final sidebarItems = _sidebar(l10n);
    final onAi = location.startsWith('/ai');

    if (isWide) {
      final selected = _indexFor(location, sidebarItems);
      return BluishBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              NavigationRail(
                extended: width >= 1100,
                selectedIndex: selected,
                onDestinationSelected: (i) => context.go(sidebarItems[i].path),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    l10n.appName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.azure,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                destinations: [
                  for (final item in sidebarItems)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
          floatingActionButton: onAi ? null : const _Fab(),
        ),
      );
    }

    final selected = _indexFor(location, mobileDestinations);
    return BluishBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: false,
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected.clamp(0, mobileDestinations.length - 1),
          onDestinationSelected: (i) => context.go(mobileDestinations[i].path),
          destinations: [
            for (final item in mobileDestinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
        floatingActionButton: onAi ? null : const _Fab(),
      ),
    );
  }
}

class _Fab extends ConsumerWidget {
  const _Fab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TapScale(
      scale: 0.92,
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/transactions/new?type=expense'),
      child: Material(
        elevation: 4,
        shadowColor: AppColors.azure.withValues(alpha: 0.4),
        color: AppColors.azure,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
