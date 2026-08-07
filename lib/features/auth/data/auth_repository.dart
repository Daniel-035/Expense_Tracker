import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/constants/platform_ids.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/demo_store.dart';
import '../../../core/utils/rate_limiter.dart';
import '../../profile/domain/user_profile.dart';
import '../../settings/domain/app_settings.dart';
import '../../accounts/domain/account.dart';

class AuthRepository {
  AuthRepository(this._ref);

  final Ref _ref;
  bool _googleReady = false;

  AppBackend get _backend => _ref.read(appBackendProvider);
  DemoStore get _demo => _ref.read(demoStoreProvider);

  Stream<UserProfile?> watchProfile() {
    if (_backend.isDemo) {
      return Stream.multi((controller) {
        controller.add(_demo.sessionUser);
        final sub = _demo.userStream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });
    }
    return _backend.auth!.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final doc = await _backend.firestore!
          .doc(FirestorePaths.user(user.uid))
          .get();
      if (!doc.exists || doc.data() == null) {
        // Just signed in — profile may still be seeding.
        return UserProfile(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'User',
          profilePhoto: user.photoURL,
          createdAt: DateTime.now(),
        );
      }
      return UserProfile.fromMap(user.uid, doc.data()!);
    });
  }

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    RateLimiter.instance.ensureAllowed('auth_register', max: 5, windowSeconds: 60);
    if (_backend.isDemo) {
      return _demo.register(name: name, email: email, password: password);
    }
    try {
      final cred = await _backend.auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name);
      await user.sendEmailVerification();
      final profile = UserProfile(
        id: user.uid,
        email: email.trim().toLowerCase(),
        name: name.trim(),
        createdAt: DateTime.now(),
      );
      await _seedUser(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e), code: e.code);
    }
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    RateLimiter.instance.ensureAllowed('auth_login', max: 8, windowSeconds: 60);
    if (_backend.isDemo) {
      return _demo.login(email, password);
    }
    try {
      final cred = await _backend.auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      final doc =
          await _backend.firestore!.doc(FirestorePaths.user(user.uid)).get();
      if (!doc.exists) {
        final profile = UserProfile(
          id: user.uid,
          email: user.email ?? email,
          name: user.displayName ?? 'User',
          createdAt: DateTime.now(),
        );
        await _seedUser(profile);
        return profile;
      }
      return UserProfile.fromMap(user.uid, doc.data()!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e), code: e.code);
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady || kIsWeb) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: PlatformIds.googleWebClientId,
    );
    _googleReady = true;
  }

  Future<UserProfile> signInWithGoogle() async {
    RateLimiter.instance.ensureAllowed('auth_google', max: 8, windowSeconds: 60);
    if (_backend.isDemo) {
      if (_demo.persistedUser?.email == 'google.user@ledgerone.app') {
        return _demo.login('google.user@ledgerone.app', 'Google123');
      }
      return _demo.register(
        name: 'Google User',
        email: 'google.user@ledgerone.app',
        password: 'Google123',
      );
    }

    try {
      final UserCredential cred;
      if (kIsWeb) {
        // Most reliable on Flutter web.
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        cred = await _backend.auth!.signInWithPopup(provider);
      } else {
        await _ensureGoogleInitialized();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw AuthException(
            'Google sign-in failed: no ID token. '
            'Add your SHA-1 in Firebase Console → Project settings → Your Android app.',
          );
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        cred = await _backend.auth!.signInWithCredential(credential);
      }

      final user = cred.user!;
      final doc =
          await _backend.firestore!.doc(FirestorePaths.user(user.uid)).get();
      if (!doc.exists) {
        final profile = UserProfile(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'User',
          profilePhoto: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _seedUser(profile);
        return profile;
      }
      return UserProfile.fromMap(user.uid, doc.data()!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapGoogleAuthError(e), code: e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      final message = e.toString().toLowerCase();
      // Missing SHA-1 / OAuth client often surfaces as "canceled" on Android.
      if (message.contains('network_error') ||
          message.contains('developer_error') ||
          message.contains('api_exception: 10') ||
          message.contains('apiexception: 10')) {
        throw AuthException(
          'Google sign-in misconfigured. In Firebase Console → Project settings → '
          'Android app (${PlatformIds.androidApplicationId}), add the SHA-1 '
          'fingerprint for this build, then retry.',
        );
      }
      if (message.contains('popup_closed') ||
          message.contains('canceled') ||
          message.contains('cancelled')) {
        throw AuthException(
          'Google sign-in was cancelled. If this keeps happening on Android, '
          'add your SHA-1 in Firebase Console → Project settings → Your Android app.',
        );
      }
      throw AuthException(
        'Google sign-in failed. Enable Google provider in Firebase Authentication '
        'and add this site to Authorized domains. Details: $e',
      );
    }
  }

  Future<void> forgotPassword(String email) async {
    RateLimiter.instance.ensureAllowed('auth_reset', max: 3, windowSeconds: 120);
    if (_backend.isDemo) {
      return;
    }
    try {
      await _backend.auth!.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e), code: e.code);
    }
  }

  Future<void> logout() async {
    if (_backend.isDemo) {
      await _demo.logout();
      return;
    }
    try {
      if (!kIsWeb) {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    await _backend.auth!.signOut();
  }

  Future<void> deleteAccount({String? password}) async {
    if (_backend.isDemo) {
      await _demo.deleteAccount();
      return;
    }
    final user = _backend.auth!.currentUser;
    if (user == null) return;

    try {
      await _reauthenticateForDeletion(user, password: password);
      await user.getIdToken(true);

      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCustomKey(
          'account_deletion_started',
          true,
        );
      }

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('deleteUserAccount');
      await callable.call<void>();

      try {
        if (!kIsWeb) {
          await _ensureGoogleInitialized();
          await GoogleSignIn.instance.signOut();
          await FirebaseCrashlytics.instance.log(
            'Account deletion completed',
          );
        }
      } catch (_) {}
      await _backend.auth!.signOut();
    } on FirebaseFunctionsException catch (e, stack) {
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'deleteUserAccount callable failed',
        );
      }
      final message = switch (e.code) {
        'failed-precondition' =>
          'Please sign in again before deleting your account.',
        'unauthenticated' => 'Please sign in again and retry.',
        _ => e.message ?? 'Could not completely delete the account.',
      };
      throw AuthException(message, code: e.code);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e), code: e.code);
    }
  }

  Future<void> _reauthenticateForDeletion(
    User user, {
    String? password,
  }) async {
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();

    if (providerIds.contains(EmailAuthProvider.PROVIDER_ID)) {
      if (password == null || password.isEmpty || user.email == null) {
        throw AuthException(
          'Enter your password to confirm account deletion.',
          code: 'password-required',
        );
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        ),
      );
      return;
    }

    if (providerIds.contains(GoogleAuthProvider.PROVIDER_ID)) {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        await user.reauthenticateWithPopup(provider);
      } else {
        await _ensureGoogleInitialized();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw AuthException(
            'Google re-authentication failed.',
            code: 'reauthentication-failed',
          );
        }
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      return;
    }

    throw AuthException(
      'Sign in again before deleting this account.',
      code: 'unsupported-provider',
    );
  }

  Future<void> _seedUser(UserProfile profile) async {
    final fs = _backend.firestore!;
    final batch = fs.batch();
    batch.set(fs.doc(FirestorePaths.user(profile.id)), profile.toMap());
    batch.set(
      fs.doc(FirestorePaths.settings(profile.id)),
      const AppSettings().toMap(),
    );
    for (final def in kDefaultCategories) {
      final ref = fs.collection(FirestorePaths.categories(profile.id)).doc();
      batch.set(ref, {
        'name': def.name,
        'type': def.type,
        'color': def.color,
        'icon': def.icon,
        'isSystem': true,
      });
    }
    final cashRef = fs.collection(FirestorePaths.accounts(profile.id)).doc();
    batch.set(cashRef, {
      'accountName': 'Cash',
      'accountType': AccountType.cash.name,
      'balance': 0,
    });
    await batch.commit();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'requires-recent-login':
        return 'Please sign in again before continuing';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  String _mapGoogleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Google sign-in was cancelled';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method';
      case 'operation-not-allowed':
        return 'Google sign-in is disabled in Firebase Authentication';
      default:
        return e.message ?? 'Google sign-in failed';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref);
});

final authStateProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authRepositoryProvider).watchProfile();
});
