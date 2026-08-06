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
