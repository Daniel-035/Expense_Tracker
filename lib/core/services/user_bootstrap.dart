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
  final Map<String, Future<void>> _pending = {};

  Future<void> ensureDefaults() {
    final uid = readCurrentUid(_ref);
    if (uid == null) {
      return Future.value();
    }
    return _pending.putIfAbsent(
      uid,
      () => _ensureDefaults().whenComplete(() {
        _pending.remove(uid);
      }),
    );
  }

  Future<void> _ensureDefaults() async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) return;
    final uid = backend.auth?.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final fs = backend.firestore!;
    final accounts = await fs
        .collection(FirestorePaths.accounts(uid))
        .limit(1)
        .get();
    final categories = await fs
        .collection(FirestorePaths.categories(uid))
        .limit(1)
        .get();

    final defaults = <String, Map<String, dynamic>>{};
    if (accounts.docs.isEmpty) {
      defaults['${FirestorePaths.accounts(uid)}/default_cash'] = {
        'accountName': 'Cash',
        'accountType': AccountType.cash.name,
        'balance': 0,
        'balanceMinor': 0,
      };
    }
    if (categories.docs.isEmpty) {
      for (final (index, def) in kDefaultCategories.indexed) {
        defaults['${FirestorePaths.categories(uid)}/default_$index'] = {
          'name': def.name,
          'type': def.type,
          'color': def.color,
          'icon': def.icon,
          'isSystem': true,
        };
      }
    }
    defaults[FirestorePaths.settings(uid)] = {
      'theme': 'system',
      'language': 'en',
      'currency': 'INR',
      'biometric': false,
      'notifications': false,
      'pinEnabled': false,
    };
    await fs.runTransaction((txn) async {
      final missing = <String>[];
      for (final path in defaults.keys) {
        if (!(await txn.get(fs.doc(path))).exists) {
          missing.add(path);
        }
      }
      for (final path in missing) {
        txn.set(fs.doc(path), defaults[path]!);
      }
    });
  }
}

final userBootstrapProvider = Provider<UserBootstrap>((ref) {
  return UserBootstrap(ref);
});
