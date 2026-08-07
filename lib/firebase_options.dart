// File generated for LedgerOne — replace via `flutterfire configure`
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Run `dart pub global activate flutterfire_cli` then
/// `flutterfire configure` to replace these placeholders with real values.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBuYD1rEZSMd5p7RP14gwAkyCUmlYBycrw',
    appId: '1:293916450719:web:c4df3df6c323c67c1e67aa',
    messagingSenderId: '293916450719',
    projectId: 'expense-tracker-70365',
    authDomain: 'expense-tracker-70365.firebaseapp.com',
    storageBucket: 'expense-tracker-70365.firebasestorage.app',
  );

  /// App Check reCAPTCHA Enterprise site key registered for Firebase Hosting.
  static const String webRecaptchaSiteKey =
      '6LdenGstAAAAAMO53eHoISDn8VEAjPDsp5Mt7Cpb';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAr952FAa6Fcfun1jNvKPBDXOhpTlRis08',
    appId: '1:293916450719:android:69ad674b66040dcf1e67aa',
    messagingSenderId: '293916450719',
    projectId: 'expense-tracker-70365',
    storageBucket: 'expense-tracker-70365.firebasestorage.app',
  );

  /// iOS Firebase app is not registered yet. Release builds refuse placeholder
  /// keys (see [main.dart]) instead of falling back to demo mode.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'expense-tracker-70365',
    storageBucket: 'expense-tracker-70365.firebasestorage.app',
    iosBundleId: 'com.ledgerone.ledgerone',
  );
}
