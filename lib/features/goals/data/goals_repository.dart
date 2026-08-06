import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/savings_goal.dart';

class GoalsRepository {
  GoalsRepository(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Stream<List<SavingsGoal>> watch() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(List.unmodifiable(store.goals));
        final sub = store.goalsStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return backend.firestore!
        .collection(FirestorePaths.goals(uid))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SavingsGoal.fromMap(d.id, d.data()))
            .toList());
  }

  Future<SavingsGoal> create({
    required String name,
    required double target,
    required DateTime deadline,
  }) async {
    final goal = SavingsGoal(
      id: _uuid.v4(),
      goalName: name,
      targetAmount: target,
      savedAmount: 0,
      deadline: deadline,
    );
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertGoal(goal);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.goals(uid))
        .doc(goal.id)
        .set(goal.toMap());
    return goal;
  }

  Future<SavingsGoal> deposit({
    required String goalId,
    required double amount,
    String? note,
  }) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).depositToGoal(
            goalId: goalId,
            amount: amount,
            note: note,
          );
    }
    final uid = backend.auth!.currentUser!.uid;
    final fs = backend.firestore!;
    final goalRef = fs.collection(FirestorePaths.goals(uid)).doc(goalId);
    return fs.runTransaction((txn) async {
      final snap = await txn.get(goalRef);
      final goal = SavingsGoal.fromMap(snap.id, snap.data()!);
      final updated = SavingsGoal(
        id: goal.id,
        goalName: goal.goalName,
        targetAmount: goal.targetAmount,
        savedAmount: goal.savedAmount + amount,
        deadline: goal.deadline,
      );
      txn.update(goalRef, updated.toMap());
      final depRef = fs.collection(FirestorePaths.goalDeposits(uid, goalId)).doc();
      txn.set(
        depRef,
        GoalDeposit(
          id: depRef.id,
          amount: amount,
          createdAt: DateTime.now(),
          note: note,
        ).toMap(),
      );
      return updated;
    });
  }

  Future<void> delete(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).deleteGoal(id);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.goals(uid))
        .doc(id)
        .delete();
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository(ref);
});

final goalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(goalsRepositoryProvider).watch();
});
