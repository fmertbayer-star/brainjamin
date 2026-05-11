import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/mascot_empty_state.dart';
import '../data/arena_models.dart';
import '../data/arena_service.dart';
import 'arena_quiz_controller.dart';

enum _ArenaResultPhase {
  loading,
  waitingEnd,
  waitingFinalize,
  ready,
  error,
  timeout,
}

/// Arena results — listens to `arenas/{id}` + `arena_results/{id}/users/{uid}`; waits for finalize.
class ArenaResultScreen extends StatefulWidget {
  const ArenaResultScreen({super.key});

  @override
  State<ArenaResultScreen> createState() => _ArenaResultScreenState();
}

class _ArenaResultScreenState extends State<ArenaResultScreen> {
  static const int _finalizeWaitTotalMs = 90000;

  final ArenaService _service = ArenaService();
  String? _wiredArenaId;

  StreamSubscription<ArenaDoc?>? _arenaSub;
  StreamSubscription<ArenaMyResult?>? _mySub;
  StreamSubscription<List<ArenaLeaderboardEntry>>? _lbSub;

  ArenaDoc? _arena;
  ArenaMyResult? _myResult;
  List<ArenaLeaderboardEntry> _leaderboard = const [];

  _ArenaResultPhase _phase = _ArenaResultPhase.loading;
  String? _errorMessage;

  Timer? _finalizeTimer;
  int _waitTimeoutMs = _finalizeWaitTotalMs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arenaId =
        GoRouterState.of(context).uri.queryParameters['arenaId']?.trim();
    if (arenaId == null || arenaId.isEmpty) {
      return;
    }
    if (_wiredArenaId == arenaId) {
      return;
    }
    _wiredArenaId = arenaId;
    _arenaSub?.cancel();
    _mySub?.cancel();
    _lbSub?.cancel();
    _finalizeTimer?.cancel();
    _finalizeTimer = null;
    _arena = null;
    _myResult = null;
    _leaderboard = const [];
    _phase = _ArenaResultPhase.loading;
    _errorMessage = null;
    _waitTimeoutMs = _finalizeWaitTotalMs;

    _arenaSub = _service.watchArena(arenaId).listen(_onArena);
    _mySub = _service.watchMyArenaResult(arenaId).listen((m) {
      if (mounted) {
        setState(() => _myResult = m);
      }
    });
    _lbSub = _service.watchArenaLeaderboard(arenaId).listen((rows) {
      if (mounted) {
        setState(() => _leaderboard = rows);
      }
    });
  }

  void _onArena(ArenaDoc? doc) {
    if (!mounted) {
      return;
    }
    setState(() {
      _arena = doc;
      _reconcilePhaseFromArena();
    });
  }

  void _reconcilePhaseFromArena() {
    final arena = _arena;
    if (arena == null) {
      if (_phase != _ArenaResultPhase.error) {
        _phase = _ArenaResultPhase.loading;
      }
      return;
    }

    if (arena.status == 'no_participants') {
      _cancelFinalizeTimer();
      _phase = _ArenaResultPhase.error;
      _errorMessage = 'This arena had no players.';
      return;
    }
    if (arena.status == 'generation_failed') {
      _cancelFinalizeTimer();
      _phase = _ArenaResultPhase.error;
      _errorMessage =
          "This one didn't quite get off the ground. Try creating a new arena.";
      return;
    }

    if (arena.finalizedAt != null) {
      _cancelFinalizeTimer();
      _phase = _ArenaResultPhase.ready;
      _errorMessage = null;
      return;
    }

    if (arena.status != 'ended') {
      _cancelFinalizeTimer();
      _phase = _ArenaResultPhase.waitingEnd;
      _errorMessage = null;
      return;
    }

    if (_phase == _ArenaResultPhase.timeout) {
      return;
    }
    if (_phase != _ArenaResultPhase.error) {
      _phase = _ArenaResultPhase.waitingFinalize;
      _tryStartFinalizeTimer();
    }
  }

  void _tryStartFinalizeTimer() {
    if (_finalizeTimer != null) {
      return;
    }
    _waitTimeoutMs = _finalizeWaitTotalMs;
    _finalizeTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onFinalizeTick,
    );
  }

  void _onFinalizeTick(Timer timer) {
    if (!mounted) {
      return;
    }
    if (_arena?.finalizedAt != null) {
      _cancelFinalizeTimer();
      setState(() {
        _phase = _ArenaResultPhase.ready;
        _errorMessage = null;
      });
      return;
    }

    final next = _waitTimeoutMs - 1000;
    if (next <= 0) {
      _cancelFinalizeTimer();
      setState(() {
        _waitTimeoutMs = 0;
        if (_phase == _ArenaResultPhase.waitingFinalize) {
          _phase = _ArenaResultPhase.timeout;
        }
      });
      return;
    }
    setState(() => _waitTimeoutMs = next);
  }

  void _cancelFinalizeTimer() {
    _finalizeTimer?.cancel();
    _finalizeTimer = null;
  }

  void _retryFinalizeWait() {
    _cancelFinalizeTimer();
    setState(() {
      _waitTimeoutMs = _finalizeWaitTotalMs;
      _phase = _ArenaResultPhase.waitingFinalize;
      _finalizeTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onFinalizeTick,
      );
    });
  }

  @override
  void dispose() {
    _cancelFinalizeTimer();
    _arenaSub?.cancel();
    _mySub?.cancel();
    _lbSub?.cancel();
    super.dispose();
  }

  List<ArenaLeaderboardEntry> _rowsForUi(ArenaDoc arena) {
    final fromDoc = arena.topHundred;
    if (fromDoc != null && fromDoc.isNotEmpty) {
      return fromDoc;
    }
    return _leaderboard;
  }

  double _avgSecondsPerQuestion(ArenaMyResult? my) {
    final ms = my?.totalAnswerMs ?? 0;
    return ms / ArenaQuizController.kQuestionCount / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final arenaId =
        GoRouterState.of(context).uri.queryParameters['arenaId']?.trim();
    if (arenaId == null || arenaId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_result_title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.arena_invite_missing_params),
        ),
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arena_result_title)),
      body: switch (_phase) {
        _ArenaResultPhase.loading => _phaseLoading(theme, l10n),
        _ArenaResultPhase.waitingEnd => _phaseWaitingEnd(theme, l10n),
        _ArenaResultPhase.waitingFinalize =>
          _phaseWaitingFinalize(theme, l10n),
        _ArenaResultPhase.ready => _phaseReady(context, theme, l10n, uid),
        _ArenaResultPhase.error => _phaseError(context, theme, l10n),
        _ArenaResultPhase.timeout => _phaseTimeout(context, theme, l10n),
      },
    );
  }

  Widget _phaseLoading(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.arena_quiz_loading,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _phaseWaitingEnd(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: MascotEmptyState(
        title: l10n.arena_result_waiting_for_end_title,
        body: l10n.arena_result_waiting_for_end_body,
      ),
    );
  }

  Widget _phaseWaitingFinalize(ThemeData theme, AppLocalizations l10n) {
    final progress =
        (_waitTimeoutMs / _finalizeWaitTotalMs).clamp(0.0, 1.0);
    final secRemaining = (_waitTimeoutMs / 1000).ceil().clamp(0, 999);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mascotAvatar(Icons.psychology_outlined),
          const SizedBox(height: 24),
          Text(
            l10n.arena_result_tallying_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.arena_result_tallying_body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  BrainjaminColors.brandOrange.withValues(alpha: 0.15),
              color: BrainjaminColors.brandOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.arena_result_seconds_remaining(secRemaining),
            style: theme.textTheme.labelMedium?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseReady(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    String uid,
  ) {
    final arena = _arena!;
    final my = _myResult;
    final rows = _rowsForUi(arena).take(10).toList();
    final ofTotal = arena.totalFinalizedParticipants ?? rows.length;
    final rank = my?.rank;
    final avgSecStr = _avgSecondsPerQuestion(my).toStringAsFixed(1);

    IconData mascotIcon;
    if (rank != null && rank <= 10) {
      mascotIcon = Icons.celebration;
    } else {
      mascotIcon = Icons.waving_hand_rounded;
    }

    Widget accentCard({required Widget child}) {
      return Card(
        color: BrainjaminColors.brandOrange.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (my != null && rank != null) ...[
          _mascotAvatar(mascotIcon, radius: 36),
          const SizedBox(height: 16),
          accentCard(
            child: Column(
              children: [
                Text(
                  '#$rank',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BrainjaminColors.brandOrangeDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.arena_result_of_total(ofTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: BrainjaminColors.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (my.xpAwarded != null && my.xpAwarded! > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.arena_result_xp_earned(my.xpAwarded!),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BrainjaminColors.brandOrange,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (my != null) ...[
          accentCard(
            child: Text(
              l10n.arena_result_correct_count(
                my.correctCount,
                ArenaQuizController.kQuestionCount,
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          accentCard(
            child: Text(
              l10n.arena_result_avg_seconds(avgSecStr),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          l10n.arena_result_top_10_heading,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.arena_result_leaderboard_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
          )
        else
          ...rows.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _leaderboardRow(
                theme,
                l10n,
                e,
                highlight: e.uid == uid,
              ),
            ),
          ),
        if (my != null && rank != null && rank > 10) ...[
          const Divider(height: 32),
          Text(
            l10n.arena_result_your_rank_section,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: BrainjaminColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
          _leaderboardRow(
            theme,
            l10n,
            ArenaLeaderboardEntry(
              rank: rank,
              uid: uid,
              displayName: l10n.arena_lobby_anonymous_player,
              correctCount: my.correctCount,
              totalAnswerMs: my.totalAnswerMs,
            ),
            highlight: true,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/arena/create'),
          child: Text(l10n.arena_result_new_arena_cta),
        ),
        TextButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.arena_result_home),
        ),
      ],
    );
  }

  Widget _leaderboardRow(
    ThemeData theme,
    AppLocalizations l10n,
    ArenaLeaderboardEntry e, {
    required bool highlight,
  }) {
    final bg = highlight
        ? BrainjaminColors.brandOrange.withValues(alpha: 0.18)
        : BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.06);
    final border = highlight
        ? Border.all(color: BrainjaminColors.brandOrange, width: 2)
        : Border.all(
            color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.2),
          );

    final secondsStr =
        (e.totalAnswerMs / 1000).toStringAsFixed(1);
    final scoreLine = e.score != null
        ? '${e.correctCount}/${ArenaQuizController.kQuestionCount} · ${e.score!.toStringAsFixed(3)}'
        : l10n.arena_result_row_summary(
            e.correctCount,
            ArenaQuizController.kQuestionCount,
            secondsStr,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#${e.rank}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              e.displayName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              scoreLine,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseError(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mascotAvatar(Icons.sentiment_dissatisfied_rounded),
          const SizedBox(height: 24),
          Text(
            l10n.arena_result_error_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? l10n.arena_result_error_body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/arena'),
            child: Text(l10n.arena_result_home),
          ),
        ],
      ),
    );
  }

  Widget _phaseTimeout(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mascotAvatar(Icons.sentiment_dissatisfied_rounded),
          const SizedBox(height: 24),
          Text(
            l10n.arena_result_timeout_title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.arena_result_timeout_body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _retryFinalizeWait,
            child: Text(l10n.arena_quiz_retry),
          ),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(l10n.arena_result_home),
          ),
        ],
      ),
    );
  }

  Widget _mascotAvatar(IconData icon, {double radius = 32}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: BrainjaminColors.brandOrange,
      child: Icon(icon, color: Colors.white, size: radius * 1.05),
    );
  }
}
