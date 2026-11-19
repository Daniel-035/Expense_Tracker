import '../../../core/utils/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/category.dart';

class CategoriesRepository {
  CategoriesRepository(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();

  Stream<List<Category>> watch() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(List.unmodifiable(store.categories));
        final sub = store.categoriesStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return backend.firestore!
        .collection(FirestorePaths.categories(uid))
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Category.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Category> create({
    required String name,
    required CategoryType type,
    required int color,
    required String icon,
  }) async {
    Money.name(name);
    final category = Category(
      id: _uuid.v4(),
      name: name,
      type: type,
      color: color,
      icon: icon,
    );
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertCategory(category);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.categories(uid))
        .doc(category.id)
        .set(category.toMap());
    return category;
  }

  Future<Category> update(Category category) async {
    Money.name(category.name);
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).upsertCategory(category);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .collection(FirestorePaths.categories(uid))
        .doc(category.id)
        .update(category.toMap());
    return category;
  }

  Future<void> delete(String id) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      if (store.transactions.any((t) => t.categoryId == id) ||
          store.budgets.any((b) => b.categoryIds.contains(id))) {
        throw StateError('This category is used in history or budgets.');
      }
      return store.deleteCategory(id);
    }
    final uid = backend.auth!.currentUser!.uid;
    final used = await backend.firestore!
        .collection(FirestorePaths.transactions(uid))
        .where('categoryId', isEqualTo: id)
        .limit(1)
        .get();
    final budgets = await backend.firestore!
        .collection(FirestorePaths.budgets(uid))
        .where('categoryIds', arrayContains: id)
        .limit(1)
        .get();
    if (used.docs.isNotEmpty || budgets.docs.isNotEmpty) {
      throw StateError('This category is used in history or budgets.');
    }
    await backend.firestore!
        .collection(FirestorePaths.categories(uid))
        .doc(id)
        .delete();
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref);
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(categoriesRepositoryProvider).watch();
});
