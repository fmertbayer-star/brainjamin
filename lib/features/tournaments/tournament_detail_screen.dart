import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/server_time_service.dart';
import '../../core/widgets/countdown_ticker.dart';
import '../../core/widgets/mascot_empty_state.dart';
import 'constants/classic_tournament_xp.dart';
import 'data/tournament.dart';
import 'state/tournament_detail_controller.dart';

/// Classic tournament info + CTA (quiz/result routes — Sprint 4.4b-ii).
class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key, required this.slotId});

  final String slotId;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  late final TournamentDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TournamentDetailController(slotId: widget.slotId);
    _controller.start();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Same fallback as [TournamentCard] until V2 category ARB exists.
  static String _categoryTitle(String categoryId) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = _controller;

    Widget body;
    if (c.isLoadingTournament && c.tournament == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (c.error != null && c.tournament == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MascotEmptyState(
              title: l10n.tournamentsErrorTitle,
              body: c.error!,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => c.start(),
              child: Text(l10n.tournamentDetailErrorRetry),
            ),
          ],
        ),
      );
    } else if (!c.isLoadingTournament && c.tournament == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MascotEmptyState(
              title: l10n.tournamentDetailNotFoundTitle,
              body: l10n.tournamentDetailNotFoundBody,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(l10n.tournamentDetailBackToList),
            ),
          ],
        ),
      );
    } else {
      final t = c.tournament!;
      body = ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      BrainjaminColors.brandOrange.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.public,
                    size: 36,
                    color: BrainjaminColors.brandOrange,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _categoryTitle(t.categoryId),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BrainjaminColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _HeroBadge(tournament: t, l10n: l10n, theme: theme),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tournamentDetailAboutHeader,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.quiz_outlined,
                  label: l10n.tournamentDetailQuestionsLabel,
                  value: l10n.tournamentDetailQuestionsValue,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.trending_up,
                  label: l10n.tournamentDetailDifficultyLabel,
                  value: l10n.tournamentDetailDifficultyValue,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: l10n.tournamentDetailWindowLabel,
                  value: _formatWindow(t.startsAt, t.endsAt),
                  theme: theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tournamentDetailXpHeader,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...ClassicTournamentXp.tierRows.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  final highlight = i == 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: highlight ?
                              BrainjaminColors.brandOrange :
                              BrainjaminColors.onSurfaceMuted.withValues(
                                alpha: 0.25,
                              ),
                        ),
                        color: highlight ?
                            BrainjaminColors.brandOrange.withValues(alpha: 0.08) :
                            Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight:
                                    highlight ? FontWeight.w700 : FontWeight.w500,
                                color: BrainjaminColors.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${row.xp} XP',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: highlight ?
                                  BrainjaminColors.brandOrangeDark :
                                  BrainjaminColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildCtaBlock(context, l10n, theme),
          ),
          if (t.isActive && c.session == null) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _EncouragementMascot(copy: l10n.tournamentDetailMascotEncouragement),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(l10n.mainTabTournaments),
      ),
      body: body,
    );
  }

  String _formatWindow(DateTime starts, DateTime ends) {
    final fmt = DateFormat.MMMd().add_jm();
    return '${fmt.format(starts.toLocal())} → ${fmt.format(ends.toLocal())}';
  }

  Widget _buildCtaBlock(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final c = _controller;
    final t = c.tournament;
    if (t == null) {
      return const SizedBox.shrink();
    }

    if (c.isLoadingSession && c.uid != null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final session = c.session;
    final now = ServerTimeService.now();

    if (session != null && session.isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BrainjaminColors.brandOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.pushNamed(
            'tournament-quiz',
            pathParameters: {'slotId': widget.slotId},
          ),
          child: Text(l10n.tournamentDetailCtaContinue),
        ),
      );
    }

    if (session != null && session.isSubmitted && !session.isFinalized) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => context.pushNamed(
            'tournament-result',
            pathParameters: {'slotId': widget.slotId},
          ),
          child: Text(l10n.tournamentDetailCtaSubmittedPending),
        ),
      );
    }

    if (session != null && session.isFinalized) {
      final rank = session.rank ?? 0;
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: BrainjaminColors.brandOrangeDark,
            side: const BorderSide(color: BrainjaminColors.brandOrange),
          ),
          onPressed: () => context.pushNamed(
            'tournament-result',
            pathParameters: {'slotId': widget.slotId},
          ),
          child: Text(l10n.tournamentDetailCtaViewResults(rank)),
        ),
      );
    }

    if (t.isEnded && session == null) {
      return Text(
        l10n.tournamentDetailCtaDidNotPlay,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: BrainjaminColors.onSurfaceMuted,
        ),
      );
    }

    if (session == null && t.isActive) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BrainjaminColors.brandOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.pushNamed(
            'tournament-quiz',
            pathParameters: {'slotId': widget.slotId},
          ),
          child: Text(l10n.tournamentDetailCtaPlayNow),
        ),
      );
    }

    if (session == null && t.isVisible && t.startsAt.isAfter(now)) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.tournamentDetailCtaStartsIn} ',
                style: theme.textTheme.labelLarge,
              ),
              CountdownTicker(
                targetUtc: t.startsAt,
                format: CountdownTicker.formatHoursMinutes,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: BrainjaminColors.brandOrangeDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.tournament,
    required this.l10n,
    required this.theme,
  });

  final Tournament tournament;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final now = ServerTimeService.now();
    Widget? badge;
    if (t.isEnded) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l10n.tournamentsStatusEnded,
          style: theme.textTheme.titleSmall?.copyWith(
            color: BrainjaminColors.onSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (t.isActive) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BrainjaminColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Text(
              '${l10n.tournamentsStatusActive} · ',
              style: theme.textTheme.titleSmall?.copyWith(
                color: BrainjaminColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            CountdownTicker(
              targetUtc: t.endsAt,
              style: theme.textTheme.titleSmall?.copyWith(
                color: BrainjaminColors.success,
                fontWeight: FontWeight.w600,
              ),
              format: (d) =>
                  '${CountdownTicker.formatHoursMinutes(d)} left',
            ),
          ],
        ),
      );
    } else if (t.isVisible && t.startsAt.isAfter(now)) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BrainjaminColors.brandOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Text(
              '${l10n.tournamentsStatusStartsIn} ',
              style: theme.textTheme.titleSmall?.copyWith(
                color: BrainjaminColors.brandOrangeDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            CountdownTicker(
              targetUtc: t.startsAt,
              style: theme.textTheme.titleSmall?.copyWith(
                color: BrainjaminColors.brandOrangeDark,
                fontWeight: FontWeight.w600,
              ),
              format: CountdownTicker.formatHoursMinutes,
            ),
          ],
        ),
      );
    }

    if (badge == null) {
      return const SizedBox.shrink();
    }
    return badge;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: BrainjaminColors.brandOrange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: BrainjaminColors.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrainjaminColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EncouragementMascot extends StatelessWidget {
  const _EncouragementMascot({required this.copy});

  final String copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: BrainjaminColors.brandOrange,
          child: Icon(Icons.psychology, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 12),
        Text(
          copy,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: BrainjaminColors.onSurfaceMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
