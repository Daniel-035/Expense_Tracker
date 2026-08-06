import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/bill.dart';

class BillsRepository {
  BillsRepository(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Stream<List<Bill>> watch() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(List.unmodifiable(store.bills));
        final sub = store.billsStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return backend.firestore!
        .collection(FirestorePaths.bills(uid))
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Bill.fromMap(d.id, d.data())).toList());
  }

  Future<Bill> create({
    required String title,
    required double amount,
    required DateTime dueDate,
    bool recurring = true,
  }) async {
    final bill = Bill(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      dueDate: dueDate,
      recurring: recurring,
    );
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertBill(bill);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.bills(uid))
        .doc(bill.id)
        .set(bill.toMap());
    return bill;
  }

  Future<Bill> markPaid(Bill bill) async {
    var next = bill.copyWith(paid: true);
    if (bill.recurring) {
      next = bill.copyWith(
        paid: false,
        dueDate: DateTime(bill.dueDate.year, bill.dueDate.month + 1, bill.dueDate.day),
      );
    }
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertBill(next);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.bills(uid))
        .doc(bill.id)
        .update(next.toMap());
    return next;
  }

  Future<void> delete(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).deleteBill(id);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.bills(uid))
        .doc(id)
        .delete();
  }
}

final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  return BillsRepository(ref);
});

final billsProvider = StreamProvider<List<Bill>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(billsRepositoryProvider).watch();
});
