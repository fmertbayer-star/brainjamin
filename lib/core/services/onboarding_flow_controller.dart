import 'package:flutter/foundation.dart';

import 'onboarding_state_service.dart';

/// Sync-readable onboarding flags for go_router [redirect]; mirrors SharedPreferences.
final class OnboardingFlowController extends ChangeNotifier {
  OnboardingFlowController({
    required bool initialCompleted,
    required bool initialAgeGatePassed,
    required bool initialAuthCompleted,
  })  : _onboardingCompleted = initialCompleted,
        _ageGatePassed = initialAgeGatePassed,
        _authCompleted = initialAuthCompleted;

  bool _onboardingCompleted;
  bool _ageGatePassed;
  bool _authCompleted;

  bool get isOnboardingCompleted => _onboardingCompleted;

  bool get isAgeGatePassed => _ageGatePassed;

  // TODO(sprint-5): Profile tab will read [isAuthCompleted] for sign-in / upgrade CTA.
  bool get isAuthCompleted => _authCompleted;

  Future<void> markAgeGatePassed() async {
    await OnboardingStateService.markAgeGatePassed();
    _ageGatePassed = true;
    notifyListeners();
  }

  Future<void> markAuthCompleted() async {
    await OnboardingStateService.markAuthCompleted();
    _authCompleted = true;
    notifyListeners();
  }

  Future<void> markOnboardingCompleted() async {
    await OnboardingStateService.markOnboardingCompleted();
    _onboardingCompleted = true;
    notifyListeners();
  }

  Future<void> reloadAuthDismissalFromPersistence() async {
    final persisted = await OnboardingStateService.isAuthCompleted();
    if (persisted != _authCompleted) {
      _authCompleted = persisted;
      notifyListeners();
    }
  }

  Future<void> resetForTesting() async {
    await OnboardingStateService.resetForTesting();
    _onboardingCompleted = false;
    _ageGatePassed = false;
    _authCompleted = false;
    notifyListeners();
  }
}
