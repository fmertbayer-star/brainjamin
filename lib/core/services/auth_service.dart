import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_result.dart';
import 'onboarding_flow_controller.dart';
import 'onboarding_state_service.dart';

/// Anonymous-first auth; permanent providers use [User.linkWithCredential] when possible
/// (Brainjamin CONTEXT § Auth — distinct from Flit's direct `signInWithCredential` on social).
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

  static Future<AuthResult> linkOrSignInWithApple() async {
    if (kIsWeb) {
      return AuthFailure('apple_web_unsupported');
    }

    final available = await SignInWithApple.isAvailable();
    if (!available) {
      return AuthFailure('apple_unavailable_platform');
    }

    AuthCredential? oauth;
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = apple.identityToken;
      if (idToken == null || idToken.isEmpty) {
        return AuthFailure('apple_missing_token');
      }

      oauth = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: apple.authorizationCode,
      );

      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        final result = await _linkAnonymous(user, oauth);
        if (result is AuthSuccess) {
          await _applyAppleDisplayNameIfNeeded(apple);
        }
        return result;
      }

      final uc = await _auth.signInWithCredential(oauth);
      final u = uc.user;
      if (u == null) return AuthFailure('no-current-user');
      await _applyAppleDisplayNameIfNeeded(apple);
      return AuthSuccess(u);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthCancelled();
      }
      return AuthFailure('apple_authorization_${e.code.name}');
    } on SignInWithAppleNotSupportedException {
      return AuthFailure('apple_unavailable_platform');
    } on FirebaseAuthException catch (e) {
      final conflict = _linkedAccountConflict(e, credential: oauth);
      if (conflict != null) return conflict;
      return AuthFailure(e.code);
    } catch (e) {
      debugPrint('[BrainjaminAuthService] Apple sign-in unexpected: $e');
      return AuthFailure('apple_unexpected');
    }
  }

  static Future<void> _applyAppleDisplayNameIfNeeded(
    AuthorizationCredentialAppleID apple,
  ) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final nameParts =
        '${apple.givenName ?? ''} ${apple.familyName ?? ''}'.trim();
    if (nameParts.isEmpty) return;
    if (u.displayName != null && u.displayName!.trim().isNotEmpty) return;
    try {
      await u.updateDisplayName(nameParts);
    } catch (_) {}
  }

  static Future<AuthResult> linkOrSignInWithGoogle() async {
    try {
      if (kIsWeb) {
        final user = _auth.currentUser;
        if (user != null && user.isAnonymous) {
          try {
            final provider = GoogleAuthProvider()
              ..addScope('email')
              ..addScope('profile');
            final uc = await user.linkWithPopup(provider);
            final u = uc.user ?? user;
            return AuthSuccess(u);
          } on FirebaseAuthException catch (e) {
            final conflict = _linkedAccountConflict(e);
            if (conflict != null) return conflict;
            return AuthFailure(e.code);
          }
        }

        final google =
            GoogleAuthProvider()..addScope('email')..addScope('profile');
        final uc = await _auth.signInWithPopup(google);
        final u = uc.user;
        return u == null ? AuthFailure('no-current-user') : AuthSuccess(u);
      }

      await GoogleSignIn.instance.initialize();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      if ((googleAuth.idToken ?? '').isEmpty) {
        return AuthFailure('google-sign-in-cancelled');
      }
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        return _linkAnonymous(user, credential);
      }

      final uc = await _auth.signInWithCredential(credential);
      final u = uc.user;
      return u == null ? AuthFailure('no-current-user') : AuthSuccess(u);
    } on FirebaseAuthException catch (e) {
      final conflict = _linkedAccountConflict(e);
      if (conflict != null) return conflict;
      return AuthFailure(e.code);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') || msg.contains('cancelled')) {
        return const AuthCancelled();
      }
      debugPrint('[BrainjaminAuthService] Google sign-in: $e');
      return AuthFailure('google-sign-in-failed');
    }
  }

  /// Anonymous users always [User.linkWithCredential] (no verification email sent).
  /// [isSignUp] is UX metadata when [fetchSignInMethodsForEmail] is unreliable.
  static Future<AuthResult> linkOrSignInWithEmail({
    required String email,
    required String password,
    required bool isSignUp,
  }) async {
    if (kDebugMode) {
      debugPrint('[BrainjaminAuthService] Email link UX isSignUp=$isSignUp');
    }
    final trimmed = email.trim();
    final user = _auth.currentUser;
    final credential =
        EmailAuthProvider.credential(email: trimmed, password: password);

    if (user == null) {
      return AuthFailure('no-current-user');
    }

    if (user.isAnonymous) {
      try {
        await user.linkWithCredential(credential);
        return AuthSuccess(_auth.currentUser!);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          return AuthSuccess(user);
        }
        final conflict = _linkedAccountConflict(e, credential: credential);
        if (conflict != null) return conflict;
        return AuthFailure(e.code);
      }
    }

    try {
      final uc = await _auth.signInWithCredential(credential);
      final u = uc.user;
      return u == null ? AuthFailure('no-current-user') : AuthSuccess(u);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(e.code);
    }
  }

  /// Replaces anonymous session permanently — only after explicit user consent in UI.
  static Future<AuthResult> signInWithCredentialReplacingAnonymous(
    AuthCredential credential,
  ) async {
    try {
      final uc = await _auth.signInWithCredential(credential);
      final u = uc.user;
      if (u == null) return AuthFailure('no-current-user');
      return AuthSuccess(u);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(e.code);
    }
  }

  static Future<void> signOut({
    OnboardingFlowController? syncDismissalNotifier,
  }) async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await OnboardingStateService.clearAuthCompleted();
    await syncDismissalNotifier?.reloadAuthDismissalFromPersistence();
  }

  static Future<AuthResult> _linkAnonymous(User user, AuthCredential credential) async {
    try {
      await user.linkWithCredential(credential);
      return AuthSuccess(_auth.currentUser!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        return AuthSuccess(_auth.currentUser!);
      }
      final conflict = _linkedAccountConflict(e, credential: credential);
      if (conflict != null) return conflict;
      return AuthFailure(e.code);
    }
  }

  static AuthLinkedToExistingAccount? _linkedAccountConflict(
    FirebaseAuthException e, {
    AuthCredential? credential,
  }) {
    if (e.code != 'credential-already-in-use' &&
        e.code != 'email-already-in-use') {
      return null;
    }
    final merged = e.credential ?? credential;
    if (merged == null) return null;
    return AuthLinkedToExistingAccount(merged);
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return digest.toString();
  }
}
