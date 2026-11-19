import '../../../core/utils/money.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/rate_limiter.dart';
import '../domain/money_transaction.dart';
import '../domain/transaction_ledger.dart';

class TransactionsRepository {
  TransactionsRepository(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Stream<List<MoneyTransaction>> watch() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(List.unmodifiable(store.transactions));
        final sub = store.transactionsStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return backend.firestore!
        .collection(FirestorePaths.transactions(uid))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MoneyTransaction.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<MoneyTransaction?> getById(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref
          .read(demoStoreProvider)
          .transactions
          .where((t) => t.id == id)
          .firstOrNull;
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to continue.');
    final doc = await backend.firestore!
        .collection(FirestorePaths.transactions(uid))
        .doc(id)
        .get();
    return doc.exists ? MoneyTransaction.fromMap(doc.id, doc.data()!) : null;
  }

  Future<MoneyTransaction> create(MoneyTransaction draft) async {
    _validate(draft);
    RateLimiter.instance.ensureAllowed('tx_write', max: 40, windowSeconds: 60);
    final tx = MoneyTransaction(
      id: draft.id.isEmpty ? _uuid.v4() : draft.id,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
      amount: draft.amount,
      transactionType: draft.transactionType,
      merchant: draft.merchant,
      notes: draft.notes,
      receiptUrl: draft.receiptUrl,
      location: draft.location,
      tags: draft.tags,
      transferAccountId: draft.transferAccountId,
      recurrence: draft.recurrence,
      nextOccurrence: draft.nextOccurrence,
      createdAt: draft.createdAt,
    );
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      final existing = store.transactions
          .where((t) => t.id == tx.id)
          .firstOrNull;
      if (existing != null) {
        if (existing != tx) {
          throw StateError('This transaction ID is already in use.');
        }
        return existing;
      }
      return store.upsertTransaction(tx);
    }
    final uid = backend.auth!.currentUser!.uid;
    final fs = backend.firestore!;
    await fs.runTransaction((txn) async {
      final txRef = fs.collection(FirestorePaths.transactions(uid)).doc(tx.id);
      final existing = await txn.get(txRef);
      if (existing.exists) {
        if (MoneyTransaction.fromMap(existing.id, existing.data()!) != tx) {
          throw StateError('This transaction ID is already in use.');
        }
        return;
      }
      await _validateCategory(txn, fs, uid, tx);
      await _applyBalanceDeltas(
        txn,
        fs,
        uid,
        transactionBalanceDeltas(tx),
        tx.id,
      );
      txn.set(txRef, tx.toMap());
    });
    return tx;
  }

  Future<MoneyTransaction> update(MoneyTransaction tx) async {
    _validate(tx);
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertTransaction(tx);
    }
    final uid = backend.auth!.currentUser!.uid;
    final fs = backend.firestore!;
    await fs.runTransaction((txn) async {
      final txRef = fs.collection(FirestorePaths.transactions(uid)).doc(tx.id);
      final oldSnapshot = await txn.get(txRef);
      if (!oldSnapshot.exists) {
        throw StateError('Transaction not found.');
      }
      final previous = MoneyTransaction.fromMap(
        oldSnapshot.id,
        oldSnapshot.data()!,
      );
      await _validateCategory(txn, fs, uid, tx);
      final deltas = combineBalanceDeltas([
        transactionBalanceDeltas(previous, reverse: true),
        transactionBalanceDeltas(tx),
      ]);
      await _applyBalanceDeltas(txn, fs, uid, deltas, tx.id);
      txn.update(txRef, tx.toMap());
    });
    return tx;
  }

  Future<void> delete(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).deleteTransaction(id);
    }
    final uid = backend.auth!.currentUser!.uid;
    final fs = backend.firestore!;
    await fs.runTransaction((txn) async {
      final txRef = fs.collection(FirestorePaths.transactions(uid)).doc(id);
      final snapshot = await txn.get(txRef);
      if (!snapshot.exists) return;
      final tx = MoneyTransaction.fromMap(snapshot.id, snapshot.data()!);
      await _applyBalanceDeltas(
        txn,
        fs,
        uid,
        transactionBalanceDeltas(tx, reverse: true),
        tx.id,
      );
      txn.delete(txRef);
    });
  }

  Future<MoneyTransaction> duplicate(MoneyTransaction source) async {
    return create(source.copyWith(id: _uuid.v4(), createdAt: DateTime.now()));
  }

  void _validate(MoneyTransaction transaction) {
    Money.minor(transaction.amount, positive: true);
    if (!transaction.amount.isFinite || transaction.amount <= 0) {
      throw StateError('Enter a valid positive amount.');
    }
    if ((transaction.merchant?.length ?? 0) > 300 ||
        (transaction.notes?.length ?? 0) > 2000 ||
        (transaction.location?.length ?? 0) > 300 ||
        transaction.tags.length > 20) {
      throw StateError('Transaction details are too long.');
    }
    if (transaction.accountId.isEmpty) {
      throw StateError('Select an account.');
    }
    if (transaction.transactionType == TransactionType.transfer) {
      transactionBalanceDeltas(transaction);
    }
  }

  Future<void> _validateCategory(
    firestore.Transaction transaction,
    firestore.FirebaseFirestore fs,
    String uid,
    MoneyTransaction tx,
  ) async {
    if (tx.transactionType == TransactionType.transfer) return;
    if (tx.categoryId.isEmpty) throw StateError('Select a category.');
    final category = await transaction.get(
      fs.collection(FirestorePaths.categories(uid)).doc(tx.categoryId),
    );
    if (!category.exists ||
        category.data()!['type'] != tx.transactionType.name) {
      throw StateError('Select a valid category for this transaction type.');
    }
  }

  Future<void> _applyBalanceDeltas(
    firestore.Transaction transaction,
    firestore.FirebaseFirestore firestoreInstance,
    String uid,
    Map<String, double> deltas,
    String operationId,
  ) async {
    final accountSnapshots = <String, firestore.DocumentSnapshot>{};
    final accountReferences = <String, firestore.DocumentReference>{};

    // Firestore requires all reads to happen before writes in a transaction.
    for (final accountId in deltas.keys) {
      final reference = firestoreInstance
          .collection(FirestorePaths.accounts(uid))
          .doc(accountId);
      accountReferences[accountId] = reference;
      accountSnapshots[accountId] = await transaction.get(reference);
    }

    for (final entry in deltas.entries) {
      final snapshot = accountSnapshots[entry.key]!;
      if (!snapshot.exists) {
        throw StateError(
          'Account not found. Restore or select a valid account and try again.',
        );
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      final balance = Money.read(data ?? {}, 'balance');
      final nextBalance = Money.add(balance, entry.value);
      transaction.update(accountReferences[entry.key]!, {
        'balance': nextBalance,
        'balanceMinor': Money.minor(nextBalance),
        'lastTransactionId': operationId,
      });
    }
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref);
});

final transactionsProvider = StreamProvider<List<MoneyTransaction>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(transactionsRepositoryProvider).watch();
});

final transactionSyncProvider = StreamProvider<String>((ref) {
  ref.watch(authUidProvider);
  final backend = ref.watch(appBackendProvider);
  if (backend.isDemo) return Stream.value('Demo data stored on this device');
  final uid = backend.auth!.currentUser?.uid;
  if (uid == null) return Stream.value('Sign in to sync');
  return backend.firestore!
      .collection(FirestorePaths.transactions(uid))
      .limit(1)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => snapshot.metadata.hasPendingWrites
            ? 'Changes waiting to sync'
            : snapshot.metadata.isFromCache
            ? 'Showing cached data; connect to post changes'
            : 'Data received from cloud',
      );
});
