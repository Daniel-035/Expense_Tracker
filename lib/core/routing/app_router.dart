import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/presentation/screens/ai_assistant_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../services/user_bootstrap.dart';
import '../providers/app_providers.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/bills/presentation/screens/bills_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/domain/money_transaction.dart';
import '../../shared/widgets/animated_widgets.dart';
import '../shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// GoRouter is created once; auth changes only refresh redirects (no full rebuild).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);

  // Backfill Cash + categories for older accounts missing seed data.
  ref.listen(authStateProvider, (prev, next) {
    final user = next.asData?.value;
    if (user != null) {
      ref.read(userBootstrapProvider).ensureDefaults().catchError((
        Object error,
      ) {
        logBackend('Default setup deferred: $error');
      });
    }
  });

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final loggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      final user = authAsync.asData?.value;
      final loading = authAsync.isLoading && !authAsync.hasValue;

      if (loading) return null;
      if (user == null && !loggingIn) return '/login';
      if (user != null && loggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            appFadePage(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            appFadePage(key: state.pageKey, child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => appFadePage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const DashboardScreen()),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (context, state) => appFadePage(
              key: state.pageKey,
              child: const TransactionsScreen(),
            ),
          ),
          GoRoute(
            path: '/accounts',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const AccountsScreen()),
          ),
          GoRoute(
            path: '/categories',
            pageBuilder: (context, state) => appFadePage(
              key: state.pageKey,
              child: const CategoriesScreen(),
            ),
          ),
          GoRoute(
            path: '/budgets',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const BudgetsScreen()),
          ),
          GoRoute(
            path: '/bills',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const BillsScreen()),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const GoalsScreen()),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const AnalyticsScreen()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const CalendarScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const ProfileScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                appFadePage(key: state.pageKey, child: const SettingsScreen()),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (context, state) => appFadePage(
              key: state.pageKey,
              child: AiAssistantScreen(key: ValueKey(readCurrentUid(ref))),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/transactions/new',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          final type = state.uri.queryParameters['type'] == 'income'
              ? TransactionType.income
              : TransactionType.expense;
          return appFadePage(
            key: state.pageKey,
            opaque: false,
            child: TransactionFormScreen(initialType: type),
          );
        },
      ),
      GoRoute(
        path: '/transactions/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => appFadePage(
          key: state.pageKey,
          opaque: false,
          child: TransactionFormScreen(
            transactionId: state.pathParameters['id'],
          ),
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    // Auto-disposed when routerProvider is disposed.
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
