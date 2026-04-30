import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Maps Firebase / Brainjamin semantic auth codes to ARB-backed copy.
String authFailureMessage(AppLocalizations l10n, String code) {
  switch (code) {
    case 'network-request-failed':
    case 'unavailable-network':
      return l10n.authErrorNetwork;
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return l10n.authErrorWrongPassword;
    case 'invalid-email':
    case 'invalid-email-verified':
      return l10n.authErrorInvalidEmail;
    case 'weak-password':
      return l10n.authErrorWeakPassword;
    case 'too-many-requests':
      return l10n.authErrorTooManyRequests;
    case 'apple_web_unsupported':
      return l10n.authAppleUnavailableWeb;
    default:
      return l10n.authErrorGeneric;
  }
}
