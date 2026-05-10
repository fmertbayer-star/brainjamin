import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import 'data/live_result.dart';
import 'data/live_top100_entry.dart';
import 'data/live_tournament.dart';
import 'state/live_result_controller.dart';

/// Live tournament results — reads finalized `live_tournaments` + optional `live_results` row.
class LiveTournamentResultScreen extends StatefulWidget {
  const LiveTournamentResultScreen({super.key, required this.ltId});

  final String ltId;

  @override
  State<LiveTournamentResultScreen> createState() =>
      _LiveTournamentResultScreenState();
}

class _LiveTournamentResultScreenState extends State<LiveTournamentResultScreen> {
  LiveResultController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = LiveResultController(ltId: widget.ltId);
    _controller!.addListener(_onCtrl);
  }

  void _onCtrl() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onCtrl);
    _controller?.dispose();
    super.dispose();
  }

  /// Matches [TournamentCard] category labels (snake_case → Title Case).
  static String _categoryDisplayTitle(String categoryId) {
    if (categoryId.isEmpty) {
      return '?';
    }
    return categoryId
        .split('_')
        .map(
          (w) =>
              w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }

  static LiveTop100Entry? _top100RowForUid(LiveTournament live, String uid) {
    for (final e in live.top100) {
      if (e.uid == uid) {
        return e;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _controller;
    if (c == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Live results')),
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          return switch (c.phase) {
            LiveResultPhase.loading => _phaseLoading(theme),
            LiveResultPhase.waitingFinalize =>
              _phaseWaitingFinalize(theme, c),
            LiveResultPhase.ready =>
              _phaseReady(context, theme, c, uid),
            LiveResultPhase.error => _phaseError(context, theme, c),
            LiveResultPhase.timeout => _phaseTimeout(context, theme, c),
          };
        },
      ),
    );
  }

  Widget _phaseLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading results…',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _phaseWaitingFinalize(ThemeData theme, LiveResultController c) {
    final progress = (c.waitTimeoutMs / LiveResultController.finalizeWaitTotalMs)
        .clamp(0.0, 1.0);
    final secRemaining = (c.waitTimeoutMs / 1000).ceil().clamp(0, 999);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mascotAvatar(Icons.psychology_outlined),
          const SizedBox(height: 24),
          Text(
            "Brainjamin's tallying the scores…",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Hang tight — results land in a moment.',
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
            '$secRemaining s remaining',
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
    LiveResultController c,
    String uid,
  ) {
    final l10n = AppLocalizations.of(context);
    final live = c.liveDoc!;
    final my = c.myResult;
    final top10 = live.top100.take(10).toList();

    final showHero =
        my != null && my.rank != null;
    final rank = my?.rank;
    final ofTotal = live.totalFinalizedParticipants ?? 0;

    IconData mascotIcon;
    if (rank != null && rank <= 10) {
      mascotIcon = Icons.celebration;
    } else {
      mascotIcon = Icons.waving_hand_rounded;
    }

    final avgSecStr = c.avgSecondsPerQuestion.toStringAsFixed(1);

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
        if (my != null && my.rank != null) ...[
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
                  'of $ofTotal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: BrainjaminColors.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (my.xpAwarded != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '+${my.xpAwarded} XP',
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
              'Correct: ${my.correctCount} / 20',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          accentCard(
            child: Text(
              'Avg. ${avgSecStr}s per question',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        accentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.self_test_stats_category_heading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (c.liveQuestionsLoading && c.categoryAccuracyRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (c.categoryAccuracyRows.isEmpty)
                Text(
                  '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BrainjaminColors.onSurfaceMuted,
                  ),
                )
              else
                ...c.categoryAccuracyRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_categoryDisplayTitle(row.categoryId)} ${row.correct}/${row.total}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Top 10',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (top10.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No leaderboard rows yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
          )
        else
          ...top10.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _leaderboardRow(
                theme,
                e,
                highlight: e.uid == uid,
              ),
            ),
          ),
        if (my != null &&
            showHero &&
            rank != null &&
            rank > 10) ...[
          const Divider(height: 32),
          Text(
            'Your rank',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: BrainjaminColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
          _inlineRankRow(theme, live, uid, my),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Back to Home'),
        ),
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('View other tournaments'),
        ),
      ],
    );
  }

  Widget _inlineRankRow(
    ThemeData theme,
    LiveTournament live,
    String uid,
    LiveResult my,
  ) {
    final row = _top100RowForUid(live, uid);
    final synthetic = LiveTop100Entry(
      rank: my.rank!,
      uid: uid,
      displayName: row?.displayName ?? '',
      correctCount: my.correctCount,
      totalAnswerMs: my.totalAnswerMs,
    );
    return _leaderboardRow(theme, synthetic, highlight: true);
  }

  Widget _leaderboardRow(
    ThemeData theme,
    LiveTop100Entry e,
    {required bool highlight,
  }) {
    final bg = highlight ?
        BrainjaminColors.brandOrange.withValues(alpha: 0.18) :
        BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.06);
    final border = highlight ?
        Border.all(color: BrainjaminColors.brandOrange, width: 2) :
        Border.all(
          color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.2),
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
            width: 56,
            child: Text(
              '${e.correctCount}/20',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseError(
    BuildContext context,
    ThemeData theme,
    LiveResultController c,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mascotAvatar(Icons.sentiment_dissatisfied_rounded),
          const SizedBox(height: 24),
          Text(
            "Couldn't load results",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            c.errorMessage ?? 'Something went wrong.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _phaseTimeout(
    BuildContext context,
    ThemeData theme,
    LiveResultController c,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mascotAvatar(Icons.sentiment_dissatisfied_rounded),
          const SizedBox(height: 24),
          Text(
            "Brainjamin's still working on the results…",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'This is taking longer than usual.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: c.retry,
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to Home'),
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
