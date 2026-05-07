import 'package:go_router/go_router.dart';

import '../core/services/onboarding_flow_controller.dart';
import '../features/arena/arena_screen.dart';
import '../features/duel/duel_screen.dart';
import '../features/daily/widgets/daily_question_screen.dart';
import '../features/daily/state/daily_question_controller.dart';
import '../features/main_shell/main_shell.dart';
import '../features/onboarding/age_blocked_screen.dart';
import '../features/onboarding/age_gate_screen.dart';
import '../features/onboarding/sign_in_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/self_test/self_test_screen.dart';

/// Single app router — no brand/admin split (Brainjamin CONTEXT).
///
/// TODO(sprint-5): [OnboardingFlowController.isAuthCompleted] does not gate routes today;
/// Profile may subscribe for CTA visibility without tightening redirect logic here.
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

        if (!completed) {
          if (!loc.startsWith('/onboarding')) {
            return '/onboarding/welcome';
          }
          return null;
        }

        if (completed && loc.startsWith('/onboarding')) {
          if (loc == '/onboarding/sign-in') {
            return null;
          }
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
          path: '/self-test',
          name: 'self-test',
          builder: (context, state) => const SelfTestScreen(),
        ),
        GoRoute(
          path: '/arena',
          name: 'arena',
          builder: (context, state) => const ArenaScreen(),
        ),
        GoRoute(
          path: '/duel',
          name: 'duel',
          builder: (context, state) => const DuelScreen(),
        ),
        GoRoute(
          path: '/daily',
          name: 'daily',
          builder: (context, state) => DailyQuestionScreen(
            controller: state.extra is DailyQuestionController ?
              state.extra! as DailyQuestionController :
              null,
          ),
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
