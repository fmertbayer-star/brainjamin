import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/server_time_service.dart';
import '../../../core/widgets/countdown_ticker.dart';
import '../data/live_tournament.dart';
import '../data/tournament.dart';
import '../data/tournament_list_item.dart';

/// Max XP for top rank — Classic V1 (hardcoded; server authority in later sprint).
const int kTournamentXpTopRank = 500;

/// TODO(V2): map [categoryId] through ARB — readable snake_case → Title Case.
class TournamentCard extends StatelessWidget {
  const TournamentCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final TournamentListItem item;

  /// Null when the card is disabled (non-interactive).
  final VoidCallback? onTap;

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
    return switch (item) {
      TournamentListItemClassic(:final tournament) =>
        _ClassicCard(tournament: tournament, onTap: onTap),
      TournamentListItemLive(:final tournament) =>
        _LiveCard(tournament: tournament, onTap: onTap),
    };
  }
}

class _ClassicCard extends StatelessWidget {
  const _ClassicCard({
    required this.tournament,
    required this.onTap,
  });

  final Tournament tournament;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = tournament;
    final now = ServerTimeService.now();

    final subtitle = l10n.tournamentsSubtitleDifficultyXp(kTournamentXpTopRank);

    Widget? badge;
    if (t.isEnded) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l10n.tournamentsStatusEnded,
          style: theme.textTheme.labelSmall?.copyWith(
            color: BrainjaminColors.onSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (t.isActive) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BrainjaminColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${l10n.tournamentsStatusActive} · ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BrainjaminColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            CountdownTicker(
              targetUtc: t.endsAt,
              style: theme.textTheme.labelSmall?.copyWith(
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BrainjaminColors.brandOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${l10n.tournamentsStatusStartsIn} ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BrainjaminColors.brandOrangeDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            CountdownTicker(
              targetUtc: t.startsAt,
              style: theme.textTheme.labelSmall?.copyWith(
                color: BrainjaminColors.brandOrangeDark,
                fontWeight: FontWeight.w600,
              ),
              format: CountdownTicker.formatHoursMinutes,
            ),
          ],
        ),
      );
    } else {
      badge = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 0,
        color: BrainjaminColors.brandOrange.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: BrainjaminColors.brandOrange.withValues(alpha: 0.35),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BrainjaminColors.brandOrange.withValues(alpha: 0.15),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.public,
                    color: BrainjaminColors.brandOrange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TournamentCard._categoryTitle(t.categoryId),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: BrainjaminColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Classic • 24h tournament',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: BrainjaminColors.onSurfaceMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: BrainjaminColors.onSurfaceMuted,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: 8),
                        badge,
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.tournament,
    required this.onTap,
  });

  final LiveTournament tournament;
  final VoidCallback? onTap;

  bool get _lateJoinDisabled =>
      tournament.isRunning && tournament.lateJoinClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tournament;
    final now = ServerTimeService.now();

    Widget metaLine;
    if (t.isScheduled && t.startsAt.isAfter(now)) {
      metaLine = Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Live • starts in ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          CountdownTicker(
            targetUtc: t.startsAt,
            style: theme.textTheme.bodySmall?.copyWith(
              color: BrainjaminColors.brandOrangeDark,
              fontWeight: FontWeight.w600,
            ),
            format: CountdownTicker.formatHoursMinutes,
          ),
        ],
      );
    } else if (t.isRunning) {
      metaLine = Text(
        'Live • happening now',
        style: theme.textTheme.bodySmall?.copyWith(
          color: BrainjaminColors.onSurfaceMuted,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      metaLine = Text(
        'Live • starting soon',
        style: theme.textTheme.bodySmall?.copyWith(
          color: BrainjaminColors.onSurfaceMuted,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Widget? lateBadge;
    if (_lateJoinDisabled) {
      lateBadge = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Late join closed',
            style: theme.textTheme.labelSmall?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final enabled = onTap != null;
    final card = Card(
      elevation: 0,
      color: BrainjaminColors.brandOrange.withValues(alpha: enabled ? 0.08 : 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: BrainjaminColors.brandOrange.withValues(alpha: enabled ? 0.35 : 0.2),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BrainjaminColors.brandOrange.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.groups_rounded,
                  color: BrainjaminColors.brandOrange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live Tournament',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: BrainjaminColors.onSurface.withValues(
                          alpha: enabled ? 1 : 0.55,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Opacity(opacity: enabled ? 1 : 0.55, child: metaLine),
                    if (lateBadge != null) lateBadge,
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: BrainjaminColors.onSurfaceMuted.withValues(
                  alpha: enabled ? 0.75 : 0.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Opacity(
        opacity: enabled ? 1 : 0.65,
        child: card,
      ),
    );
  }
}
