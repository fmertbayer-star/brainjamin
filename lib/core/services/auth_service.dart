import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Silent anonymous sign-in runs during bootstrap; gameplay stays available without
/// linking. Apple / Google / email use `linkWithCredential` in Sprint 1.5 to convert
/// the existing anonymous user.
final class BrainjaminAuthService {
  BrainjaminAuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static bool get isSignedIn => currentUser != null;

  static bool get isAnonymous => currentUser?.isAnonymous ?? false;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Ensures an anonymous session exists. Idempotent; failures are logged, not thrown.
  static Future<void> ensureSignedIn() async {
    if (currentUser != null) return;
    try {
      await _auth.signInAnonymously().timeout(const Duration(seconds: 10));
    } on TimeoutException catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace);
      debugPrint('[BrainjaminAuthService] signInAnonymously timeout: $e');
    } on FirebaseAuthException catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace);
      debugPrint(
        '[BrainjaminAuthService] signInAnonymously failed: ${e.code} ${e.message}',
      );
    }
  }
}
