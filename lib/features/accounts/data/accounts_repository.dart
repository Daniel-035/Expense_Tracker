import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../transactions/domain/money_transaction.dart';
import '../domain/account.dart';

class AccountsRepository {
  AccountsRepository(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Stream<List<Account>> watchAccounts() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(List.unmodifiable(store.accounts));
        final sub = store.accountsStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return backend.firestore!
        .collection(FirestorePaths.accounts(uid))
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Account.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    double balance = 0,
  }) async {
    final backend = _ref.read(appBackendProvider);
    final account = Account(
      id: _uuid.v4(),
      accountName: name,
      accountType: type,
      balance: balance,
    );
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertAccount(account);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.accounts(uid))
        .doc(account.id)
        .set(account.toMap());
    return account;
  }

  Future<Account> update(Account account) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertAccount(account);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.accounts(uid))
        .doc(account.id)
        .update(account.toMap());
    return account;
  }

  Future<void> delete(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).deleteAccountById(id);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.accounts(uid))
        .doc(id)
        .delete();
  }

  Future<void> transfer({
    required String fromId,
    required String toId,
    required double amount,
    String? notes,
  }) async {
    if (fromId == toId) {
      throw StateError('Transfer accounts must be different.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw StateError('Enter a valid positive amount.');
    }
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref
          .read(demoStoreProvider)
          .transfer(fromId: fromId, toId: toId, amount: amount, notes: notes);
    }
    final uid = backend.auth!.currentUser!.uid;
    final fs = backend.firestore!;
    await fs.runTransaction((txn) async {
      final fromRef = fs.collection(FirestorePaths.accounts(uid)).doc(fromId);
      final toRef = fs.collection(FirestorePaths.accounts(uid)).doc(toId);
      final fromSnap = await txn.get(fromRef);
      final toSnap = await txn.get(toRef);
      final fromBal = (fromSnap.data()?['balance'] as num?)?.toDouble() ?? 0;
      final toBal = (toSnap.data()?['balance'] as num?)?.toDouble() ?? 0;
      txn.update(fromRef, {'balance': fromBal - amount});
      txn.update(toRef, {'balance': toBal + amount});
      final txRef = fs.collection(FirestorePaths.transactions(uid)).doc();
      txn.set(
        txRef,
        MoneyTransaction(
          id: txRef.id,
          accountId: fromId,
          categoryId: '',
          amount: amount,
          transactionType: TransactionType.transfer,
          transferAccountId: toId,
          notes: notes ?? 'Transfer',
          createdAt: DateTime.now(),
        ).toMap(),
      );
    });
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref);
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(accountsRepositoryProvider).watchAccounts();
});
