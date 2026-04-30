import 'package:go_router/go_router.dart';

import '../core/services/onboarding_flow_controller.dart';
import '../features/main_shell/main_shell.dart';
import '../features/onboarding/age_blocked_screen.dart';
import '../features/onboarding/age_gate_screen.dart';
import '../features/onboarding/sign_in_screen.dart';
import '../features/onboarding/welcome_screen.dart';

/// Single app router — no brand/admin split (Brainjamin CONTEXT).
final class AppRouter {
  AppRouter._();

  static GoRouter create({
    required OnboardingFlowController onboardingController,
  }) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: onboardingController,
      redirect: (context, state) {
        final completed = onboardingController.isOnboardingCompleted;
        final loc = state.uri.path;
        if (!completed && loc == '/') {
          return '/onboarding/welcome';
        }
        if (completed && loc.startsWith('/onboarding')) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'main',
          builder: (context, state) => const MainShell(),
        ),
        GoRoute(
          path: '/onboarding/welcome',
          name: 'onboarding-welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/onboarding/age-gate',
          name: 'onboarding-age-gate',
          builder: (context, state) => const AgeGateScreen(),
        ),
        GoRoute(
          path: '/onboarding/age-blocked',
          name: 'onboarding-age-blocked',
          builder: (context, state) => const AgeBlockedScreen(),
        ),
        GoRoute(
          path: '/onboarding/sign-in',
          name: 'onboarding-sign-in',
          builder: (context, state) => const SignInScreen(),
        ),
      ],
    );
  }
}
