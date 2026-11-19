import '../../../core/utils/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/budget.dart';

class BudgetsRepository {
  BudgetsRepository(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Stream<List<Budget>> watch() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(List.unmodifiable(store.budgets));
        final sub = store.budgetsStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return backend.firestore!
        .collection(FirestorePaths.budgets(uid))
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Budget.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Budget> create({
    required double amount,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) async {
    Money.minor(amount, positive: true);
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final budget = Budget(
      id: _uuid.v4(),
      amount: amount,
      period: period,
      categoryIds: List.unmodifiable(categoryIds.toSet()),
      monthKey: monthKey,
    );
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertBudget(budget);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.budgets(uid))
        .doc(budget.id)
        .set(budget.toMap());
    return budget;
  }

  Future<void> delete(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).deleteBudget(id);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.budgets(uid))
        .doc(id)
        .delete();
  }
}

final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  return BudgetsRepository(ref);
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(budgetsRepositoryProvider).watch();
});

/// Budgets with [spent] computed from live expense transactions.
final liveBudgetsProvider = Provider<AsyncValue<List<Budget>>>((ref) {
  final budgetsAsync = ref.watch(budgetsProvider);
  final txsAsync = ref.watch(transactionsProvider);

  return budgetsAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (budgets) {
      return txsAsync.when(
        loading: () => const AsyncLoading(),
        error: (error, stack) => AsyncError(error, stack),
        data: (txs) =>
            AsyncData(budgets.map((b) => b.withLiveSpent(txs)).toList()),
      );
    },
  );
});

/// Budgets are recurring limits. This previews the selected week/month using
/// the current rule, rather than presenting it as an archived budget snapshot.
final budgetsForDateProvider =
    Provider.family<AsyncValue<List<Budget>>, DateTime>((ref, at) {
      final budgets = ref.watch(budgetsProvider);
      final transactions = ref.watch(transactionsProvider);
      return budgets.when(
        loading: () => const AsyncLoading(),
        error: (e, st) => AsyncError(e, st),
        data: (rules) => transactions.when(
          loading: () => const AsyncLoading(),
          error: (e, st) => AsyncError(e, st),
          data: (entries) => AsyncData(
            rules.map((b) => b.withLiveSpent(entries, now: at)).toList(),
          ),
        ),
      );
    });
