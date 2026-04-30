import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding completion and age-gate pass only. Birth year/month are
/// intentionally not stored—only the boolean pass flag (COPPA-aligned minimization, PR-11).
final class OnboardingStateService {
  OnboardingStateService._();

  static const String _keyOnboardingCompleted = 'brainjamin.onboarding.completed';
  static const String _keyAgeGatePassed = 'brainjamin.age_gate.passed';

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
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
  }
}
