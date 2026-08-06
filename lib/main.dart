import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_l10n.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/demo_store.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/data/settings_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppBackend backend;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      // Web App Check for Firebase AI Logic uses reCAPTCHA Enterprise.
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
    } catch (e) {
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
  } catch (e) {
    logBackend('Firebase unavailable ($e) — using demo mode');
    await DemoStore.instance.load();
    backend = AppBackend(mode: BackendMode.demo);
  }

  final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
  if (!backend.isDemo && apiKey.startsWith('YOUR_')) {
    logBackend('Placeholder Firebase keys detected — using demo mode');
    await DemoStore.instance.load();
    backend = AppBackend(mode: BackendMode.demo);
  }

  runApp(
    ProviderScope(
      overrides: [
        appBackendProvider.overrideWithValue(backend),
      ],
      child: const LedgerOneApp(),
    ),
  );
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

    return MaterialApp.router(
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
