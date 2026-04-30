import 'package:firebase_auth/firebase_auth.dart';

/// Outcome of social / email auth attempts (Sprint 1.5).
sealed class AuthResult {
  const AuthResult();
}

final class AuthSuccess extends AuthResult {
  AuthSuccess(this.user);

  final User user;
}

/// Credential belongs to an existing permanent account; offer explicit switch (drops anonymous progress).
final class AuthLinkedToExistingAccount extends AuthResult {
  AuthLinkedToExistingAccount(this.credential);

  final AuthCredential credential;
}

final class AuthFailure extends AuthResult {
  AuthFailure(this.code);

  /// Firebase error code or a Brainjamin semantic code (e.g. `apple_web_unsupported`).
  final String code;
}

final class AuthCancelled extends AuthResult {
  const AuthCancelled();
}
