import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding completion, auth-dismissal tracking, and age-gate pass only.
/// Birth year/month are intentionally not stored—only boolean pass flags (PR-11).
final class OnboardingStateService {
  OnboardingStateService._();

  static const String _keyOnboardingCompleted = 'brainjamin.onboarding.completed';
  static const String _keyAgeGatePassed = 'brainjamin.age_gate.passed';
  static const String _keyAuthDismissalTracking =
      'brainjamin.auth.onboarding_completed';

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  /// True once the sign-in surface has been resolved (OAuth success or anonymous CTA).
  static Future<bool> isAuthCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAuthDismissalTracking) ?? false;
  }

  static Future<void> markAuthCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAuthDismissalTracking, true);
  }

  static Future<void> clearAuthCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthDismissalTracking);
  }

  static Future<bool> isAgeGatePassed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAgeGatePassed) ?? false;
  }

  static Future<void> markAgeGatePassed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAgeGatePassed, true);
  }

  /// Clears persisted onboarding flags (tests only).
  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove(_keyAgeGatePassed);
    await prefs.remove(_keyAuthDismissalTracking);
  }
}
