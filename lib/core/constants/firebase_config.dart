/// Firebase / Cloud Functions configuration (single source of truth).
class FirebaseConfig {
  FirebaseConfig._();

  /// Region for callable Cloud Functions. Must match
  /// `setGlobalOptions({region})` in functions/src/index.ts.
  static const String functionsRegion = 'us-central1';

  /// Realtime Database URL — used for `.info/serverTimeOffset` reads via
  /// ServerTimeService.
  static const String rtdbUrl =
      'https://brainjamin-prod-app-default-rtdb.firebaseio.com';
}
