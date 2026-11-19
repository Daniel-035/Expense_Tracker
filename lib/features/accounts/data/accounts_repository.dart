import '../../../core/utils/money.dart';
import '../../transactions/data/transactions_repository.dart';
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
    Money.name(name);
    Money.minor(balance);
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
    Money.name(account.accountName);
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      final current = store.accounts.firstWhere((a) => a.id == account.id);
      return store.upsertAccount(
        current.copyWith(
          accountName: account.accountName,
          accountType: account.accountType,
        ),
      );
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.accounts(uid))
        .doc(account.id)
        .update({
          'accountName': account.accountName,
          'accountType': account.accountType.name,
        });
    return account;
  }

  Future<void> delete(String id) => setArchived(id, true);

  Future<void> setArchived(String id, bool archived) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      await store.upsertAccount(
        store.accounts
            .firstWhere((a) => a.id == id)
            .copyWith(archived: archived),
      );
      return;
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.accounts(uid))
        .doc(id)
        .update({'archived': archived});
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
    await _ref
        .read(transactionsRepositoryProvider)
        .create(
          MoneyTransaction(
            id: _uuid.v4(),
            accountId: fromId,
            transferAccountId: toId,
            categoryId: '',
            amount: amount,
            transactionType: TransactionType.transfer,
            notes: notes ?? 'Transfer',
            createdAt: DateTime.now(),
          ),
        );
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref);
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(accountsRepositoryProvider).watchAccounts();
});
