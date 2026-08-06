import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../constants/default_categories.dart';
import '../providers/app_providers.dart';
import '../../features/accounts/domain/account.dart';

/// Ensures a signed-in Firebase user has at least Cash + default categories.
/// Fixes empty dropdowns that block adding income/expense on web.
class UserBootstrap {
  UserBootstrap(this._ref);

  final Ref _ref;

  Future<void> ensureDefaults() async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) return;
    final uid = backend.auth?.currentUser?.uid;
    if (uid == null) return;

    final fs = backend.firestore!;
    final accounts = await fs
        .collection(FirestorePaths.accounts(uid))
        .limit(1)
        .get();
    final categories = await fs
        .collection(FirestorePaths.categories(uid))
        .limit(1)
        .get();

    if (accounts.docs.isNotEmpty && categories.docs.isNotEmpty) return;

    final batch = fs.batch();
    if (categories.docs.isEmpty) {
      for (final def in kDefaultCategories) {
        final ref = fs.collection(FirestorePaths.categories(uid)).doc();
        batch.set(ref, {
          'name': def.name,
          'type': def.type,
          'color': def.color,
          'icon': def.icon,
          'isSystem': true,
        });
      }
    }
    if (accounts.docs.isEmpty) {
      final cashRef = fs.collection(FirestorePaths.accounts(uid)).doc();
      batch.set(cashRef, {
        'accountName': 'Cash',
        'accountType': AccountType.cash.name,
        'balance': 0,
      });
    }

    // Settings doc if missing
    final settings = await fs.doc(FirestorePaths.settings(uid)).get();
    if (!settings.exists) {
      batch.set(fs.doc(FirestorePaths.settings(uid)), {
        'theme': 'system',
        'language': 'en',
        'currency': 'INR',
        'biometric': false,
        'notifications': true,
        'pinEnabled': false,
      });
    }

    await batch.commit();
  }
}

final userBootstrapProvider = Provider<UserBootstrap>((ref) {
  return UserBootstrap(ref);
});
