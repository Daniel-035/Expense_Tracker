import '../../../core/utils/money.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._ref);

  final Ref _ref;

  Stream<AppSettings> watch() {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      final store = _ref.read(demoStoreProvider);
      return Stream.multi((controller) {
        controller.add(store.settings);
        final sub = store.settingsStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    final uid = backend.auth!.currentUser?.uid;
    if (uid == null) return Stream.value(const AppSettings());
    return backend.firestore!
        .doc(FirestorePaths.settings(uid))
        .snapshots()
        .map((snap) => AppSettings.fromMap(snap.data()));
  }

  Future<void> update(AppSettings settings) async {
    if (!['INR', 'USD', 'EUR', 'GBP'].contains(settings.currency) ||
        !['en', 'hi'].contains(settings.language) ||
        !['system', 'light', 'dark'].contains(settings.theme)) {
      throw StateError('Invalid settings.');
    }
    final sessionUid = readCurrentUid(_ref);
    if (sessionUid == null) throw StateError('Sign in to update settings.');
    final current = await watch().first;
    if (readCurrentUid(_ref) != sessionUid) {
      throw StateError('Session changed.');
    }
    if (current.currency != settings.currency) {
      final backend = _ref.read(appBackendProvider);
      final hasMoney = backend.isDemo
          ? _ref.read(demoStoreProvider).budgets.isNotEmpty ||
                _ref.read(demoStoreProvider).bills.isNotEmpty ||
                _ref.read(demoStoreProvider).goals.isNotEmpty ||
                _ref.read(demoStoreProvider).transactions.isNotEmpty ||
                _ref.read(demoStoreProvider).accounts.any((a) => a.balance != 0)
          : (await backend.firestore!
                        .collection(
                          FirestorePaths.transactions(
                            backend.auth!.currentUser!.uid,
                          ),
                        )
                        .limit(1)
                        .get())
                    .docs
                    .isNotEmpty ||
                (await backend.firestore!
                        .collection(
                          FirestorePaths.accounts(
                            backend.auth!.currentUser!.uid,
                          ),
                        )
                        .get())
                    .docs
                    .any((a) => Money.read(a.data(), 'balance') != 0) ||
                (await Future.wait(
                  [
                    FirestorePaths.budgets(sessionUid),
                    FirestorePaths.bills(sessionUid),
                    FirestorePaths.goals(sessionUid),
                  ].map(
                    (path) =>
                        backend.firestore!.collection(path).limit(1).get(),
                  ),
                )).any((snap) => snap.docs.isNotEmpty);
      if (hasMoney) {
        throw StateError(
          'Ledger currency cannot change after money is recorded. Export your data before starting a ledger in another currency.',
        );
      }
    }
    if (readCurrentUid(_ref) != sessionUid) {
      throw StateError('Session changed.');
    }
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).updateSettings(settings);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .doc(FirestorePaths.settings(uid))
        .set(settings.toMap(), SetOptions(merge: true));
  }
}

class ProfileRepository {
  ProfileRepository(this._ref);

  final Ref _ref;

  Future<void> update(UserProfile profile) async {
    Money.name(profile.name);
    if (readCurrentUid(_ref) != profile.id) {
      throw StateError('Session changed.');
    }
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _ref.read(demoStoreProvider).updateProfile(profile);
    }
    final uid = backend.auth!.currentUser!.uid;
    await backend.firestore!
        .doc(FirestorePaths.user(uid))
        .update(profile.toMap());
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});

final settingsProvider = StreamProvider<AppSettings>((ref) {
  ref.watch(authUidProvider);
  return ref.watch(settingsRepositoryProvider).watch();
});
