import '../../../core/utils/recurrence.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../accounts/domain/account.dart';
import '../../../core/utils/money.dart';
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
        .map(
          (snap) => snap.docs.map((d) => Bill.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Bill> create({
    required String title,
    required double amount,
    required DateTime dueDate,
    bool recurring = true,
  }) async {
    Money.name(title);
    Money.minor(amount, positive: true);
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

  Future<Bill> markPaid(
    Bill bill, {
    required String accountId,
    required String categoryId,
  }) async {
    if (bill.paid) throw StateError('This bill has already been paid.');
    Money.minor(bill.amount, positive: true);
    if (accountId.isEmpty || categoryId.isEmpty) {
      throw StateError('Select an account and expense category.');
    }
    final next = bill.recurring
        ? bill.copyWith(
            paid: false,
            dueDate: nextOccurrence(
              bill.dueDate,
              RecurrenceInterval.monthly,
              anchorDay: bill.billingDay,
            ),
          )
        : bill.copyWith(paid: true);
    final paymentId = 'bill_${bill.id}_${bill.dueDate.millisecondsSinceEpoch}';
    final payment = MoneyTransaction(
      id: paymentId,
      accountId: accountId,
      categoryId: categoryId,
      amount: bill.amount,
      transactionType: TransactionType.expense,
      merchant: bill.title,
      notes: 'Bill payment due ${bill.dueDate.toIso8601String()}',
      createdAt: DateTime.now(),
    );
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      if (store.transactions.any((t) => t.id == paymentId)) {
        return store.bills.firstWhere((b) => b.id == bill.id);
      }
      await _ref.read(transactionsRepositoryProvider).create(payment);
      return store.upsertBill(next);
    }
    final uid = backend.auth!.currentUser!.uid;
    final fs = backend.firestore!;
    final billRef = fs.collection(FirestorePaths.bills(uid)).doc(bill.id);
    final paymentRef = fs
        .collection(FirestorePaths.transactions(uid))
        .doc(paymentId);
    final accountRef = fs
        .collection(FirestorePaths.accounts(uid))
        .doc(accountId);
    final categoryRef = fs
        .collection(FirestorePaths.categories(uid))
        .doc(categoryId);
    await fs.runTransaction((txn) async {
      final current = await txn.get(billRef);
      final existing = await txn.get(paymentRef);
      if (existing.exists) return;
      if (!current.exists ||
          Bill.fromMap(current.id, current.data()!) != bill ||
          current.data()!['paid'] == true) {
        throw StateError('Bill changed. Refresh and try again.');
      }
      final account = await txn.get(accountRef);
      final category = await txn.get(categoryRef);
      if (!account.exists || account.data()!['archived'] == true) {
        throw StateError('Select an active account.');
      }
      if (!category.exists || category.data()!['type'] != 'expense') {
        throw StateError('Select an expense category.');
      }
      final balance = Money.add(
        Account.fromMap(account.id, account.data()!).balance,
        -bill.amount,
      );
      txn.update(accountRef, {
        'balance': balance,
        'balanceMinor': Money.minor(balance),
        'lastTransactionId': paymentId,
      });
      txn.set(paymentRef, {
        ...payment.toMap(),
        'billId': bill.id,
        'billDueDate': bill.dueDate.toIso8601String(),
      });
      txn.update(billRef, {...next.toMap(), 'lastPaymentId': paymentId});
    });
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
