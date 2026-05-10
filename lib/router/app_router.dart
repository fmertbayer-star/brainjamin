import 'package:go_router/go_router.dart';

import '../core/services/onboarding_flow_controller.dart';
import '../features/arena/arena_screen.dart';
import '../features/arena/widgets/arena_create_wizard_screen.dart';
import '../features/arena/widgets/arena_invite_share_screen.dart';
import '../features/arena/widgets/arena_join_code_screen.dart';
import '../features/arena/widgets/arena_lobby_screen.dart';
import '../features/arena/widgets/arena_quiz_screen.dart';
import '../features/arena/widgets/arena_result_screen.dart';
import '../features/duel/duel_screen.dart';
import '../features/duel/widgets/duel_match_type_screen.dart';
import '../features/duel/widgets/duel_join_code_screen.dart';
import '../features/duel/widgets/duel_quiz_screen.dart';
import '../features/duel/widgets/duel_invite_share_screen.dart';
import '../features/duel/widgets/duel_result_screen.dart';
import '../features/daily/widgets/daily_question_screen.dart';
import '../features/daily/state/daily_question_controller.dart';
import '../features/main_shell/main_shell.dart';
import '../features/onboarding/age_blocked_screen.dart';
import '../features/onboarding/age_gate_screen.dart';
import '../features/onboarding/sign_in_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/self_test/self_test_screen.dart';
import '../features/tournaments/classic_quiz_screen.dart';
import '../features/tournaments/classic_result_screen.dart';
import '../features/tournaments/live_tournament_lobby_screen.dart';
import '../features/tournaments/live_tournament_quiz_screen.dart';
import '../features/tournaments/live_tournament_result_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';

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
          routes: [
            GoRoute(
              path: 'create',
              name: 'arena-create',
              builder: (context, state) => const ArenaCreateWizardScreen(),
            ),
            GoRoute(
              path: 'invite-share',
              name: 'arena-invite-share',
              builder: (context, state) => const ArenaInviteShareScreen(),
            ),
            GoRoute(
              path: 'join',
              name: 'arena-join',
              builder: (context, state) => const ArenaJoinCodeScreen(),
            ),
            GoRoute(
              path: 'lobby',
              name: 'arena-lobby',
              builder: (context, state) => const ArenaLobbyScreen(),
            ),
            GoRoute(
              path: 'quiz',
              name: 'arena-quiz',
              builder: (context, state) => const ArenaQuizScreen(),
            ),
            GoRoute(
              path: 'result',
              name: 'arena-result',
              builder: (context, state) => const ArenaResultScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/duel',
          name: 'duel',
          builder: (context, state) => const DuelScreen(),
          routes: [
            GoRoute(
              path: 'match-type',
              name: 'duel-match-type',
              builder: (context, state) => const DuelMatchTypeScreen(),
            ),
            GoRoute(
              path: 'invite-share',
              name: 'duel-invite-share',
              builder: (context, state) => const DuelInviteShareScreen(),
            ),
            GoRoute(
              path: 'join',
              name: 'duel-join',
              builder: (context, state) => const DuelJoinCodeScreen(),
            ),
            GoRoute(
              path: 'quiz',
              name: 'duel-quiz',
              builder: (context, state) => const DuelQuizScreen(),
            ),
            GoRoute(
              path: 'result',
              name: 'duel-result',
              builder: (context, state) => const DuelResultScreen(),
            ),
          ],
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
          path: '/live-tournament/:ltId/quiz',
          name: 'live-tournament-quiz',
          builder: (context, state) {
            final ltId = state.pathParameters['ltId'] ?? '';
            return LiveTournamentQuizScreen(ltId: ltId);
          },
        ),
        GoRoute(
          path: '/live-tournament/:ltId/result',
          name: 'live-tournament-result',
          builder: (context, state) {
            final ltId = state.pathParameters['ltId'] ?? '';
            return LiveTournamentResultScreen(ltId: ltId);
          },
        ),
        GoRoute(
          path: '/live-tournament/:ltId',
          name: 'live-tournament-lobby',
          builder: (context, state) {
            final ltId = state.pathParameters['ltId'] ?? '';
            return LiveTournamentLobbyScreen(ltId: ltId);
          },
        ),
        GoRoute(
          path: '/tournament/:slotId',
          name: 'tournament-detail',
          builder: (context, state) {
            final slotId = state.pathParameters['slotId'];
            if (slotId == null || slotId.isEmpty) {
              return const TournamentDetailScreen(slotId: '');
            }
            return TournamentDetailScreen(slotId: slotId);
          },
        ),
        GoRoute(
          path: '/tournament/:slotId/quiz',
          name: 'tournament-quiz',
          builder: (context, state) {
            final slotId = state.pathParameters['slotId'];
            if (slotId == null || slotId.isEmpty) {
              return const TournamentDetailScreen(slotId: '');
            }
            return ClassicQuizScreen(slotId: slotId);
          },
        ),
        GoRoute(
          path: '/tournament/:slotId/result',
          name: 'tournament-result',
          builder: (context, state) {
            final slotId = state.pathParameters['slotId'];
            if (slotId == null || slotId.isEmpty) {
              return const TournamentDetailScreen(slotId: '');
            }
            return ClassicResultScreen(slotId: slotId);
          },
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
