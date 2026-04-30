import 'package:flutter/foundation.dart';

import 'onboarding_state_service.dart';

/// Sync-readable onboarding flags for go_router [redirect]; mirrors SharedPreferences.
final class OnboardingFlowController extends ChangeNotifier {
  OnboardingFlowController({
    required bool initialCompleted,
    required bool initialAgeGatePassed,
  })  : _onboardingCompleted = initialCompleted,
        _ageGatePassed = initialAgeGatePassed;

  bool _onboardingCompleted;
  bool _ageGatePassed;

  bool get isOnboardingCompleted => _onboardingCompleted;

  bool get isAgeGatePassed => _ageGatePassed;

  Future<void> markAgeGatePassed() async {
    await OnboardingStateService.markAgeGatePassed();
    _ageGatePassed = true;
    notifyListeners();
  }

  Future<void> markOnboardingCompleted() async {
    await OnboardingStateService.markOnboardingCompleted();
    _onboardingCompleted = true;
    notifyListeners();
  }

  Future<void> resetForTesting() async {
    await OnboardingStateService.resetForTesting();
    _onboardingCompleted = false;
    _ageGatePassed = false;
    notifyListeners();
  }
}
