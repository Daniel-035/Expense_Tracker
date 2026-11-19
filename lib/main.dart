import 'package:intl/intl.dart';
import 'core/l10n/app_text.dart';
import 'core/shell/device_lock_gate.dart';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/startup_failure_app.dart';
import 'core/l10n/app_l10n.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/demo_store.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/data/settings_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  if (firebaseOptions.apiKey.startsWith('YOUR_')) {
    if (kReleaseMode) {
      runApp(const StartupFailureApp());
      return;
    }
    logBackend('Placeholder Firebase keys detected — using demo mode');
    await DemoStore.instance.load();
    _runLedgerOne(AppBackend(mode: BackendMode.demo));
    return;
  }

  AppBackend backend;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    await _configureCrashlytics();

    try {
      // Firebase Hosting is registered with a score-based Enterprise key.
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(
          DefaultFirebaseOptions.webRecaptchaSiteKey,
        ),
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } catch (e, stack) {
      if (!kIsWeb && kReleaseMode) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: true,
          reason: 'Firebase App Check activation failed',
        );
        rethrow;
      }
      logBackend('App Check skipped: $e');
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    backend = AppBackend(
      mode: BackendMode.firebase,
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instanceFor(
        bucket: 'expense-tracker-70365.firebasestorage.app',
      ),
    );
    logBackend('Using Firebase backend');
  } catch (e, stack) {
    if (Firebase.apps.isNotEmpty && !kIsWeb && kReleaseMode) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        fatal: true,
        reason: 'Firebase startup failed',
      );
    }
    if (kReleaseMode) {
      runApp(const StartupFailureApp());
      return;
    }
    logBackend('Firebase unavailable ($e) — using demo mode');
    await DemoStore.instance.load();
    backend = AppBackend(mode: BackendMode.demo);
  }

  _runLedgerOne(backend);
}

void _runLedgerOne(AppBackend backend) {
  runApp(
    ProviderScope(
      overrides: [appBackendProvider.overrideWithValue(backend)],
      child: const LedgerOneApp(),
    ),
  );
}

Future<void> _configureCrashlytics() async {
  if (kIsWeb) return;

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    kReleaseMode,
  );
  if (!kReleaseMode) return;

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

class LedgerOneApp extends ConsumerWidget {
  const LedgerOneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeKey = ref.watch(
      settingsProvider.select((async) => async.asData?.value.theme ?? 'system'),
    );
    final language = ref.watch(
      settingsProvider.select((async) => async.asData?.value.language ?? 'en'),
    );
    final themeMode = switch (themeKey) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = Locale(language == 'hi' ? 'hi' : 'en');
    Intl.defaultLocale = locale.languageCode;

    return MaterialApp.router(
      builder: (context, child) => ref
          .watch(authUidProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const Center(
              child: AppText('Could not restore session. Restart to retry.'),
            ),
            data: (uid) => uid == null
                ? child!
                : DeviceLockGate(key: ValueKey(uid), uid: uid, child: child!),
          ),
      title: 'LedgerOne',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppL10n.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
