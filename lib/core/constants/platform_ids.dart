/// Canonical platform / OAuth identifiers for LedgerOne.
///
/// Android applicationId, Firebase Android app package, and Google Sign-In
/// clients must stay aligned with this file.
class PlatformIds {
  /// Firebase / Play Store Android application id.
  static const String androidApplicationId = 'com.ledgerone.appshot.com';

  /// Planned iOS bundle id (Firebase iOS app not configured yet).
  static const String iosBundleId = 'com.ledgerone.ledgerone';

  /// Firebase Web OAuth client (type 3). Used as Google Sign-In
  /// [serverClientId] on Android/iOS and as the web meta client id.
  static const String googleWebClientId =
      '293916450719-9muqkj0gjspieqoumad04kqcius43q21.apps.googleusercontent.com';
}
