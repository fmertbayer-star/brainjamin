import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/countdown_ticker.dart';
import '../../tournaments/data/tournament_list_item.dart';
import '../../tournaments/state/tournaments_controller.dart';
import '../../tournaments/widgets/tournament_card.dart';

/// Tournaments tab — Classic listing + empty state with next-slot countdown.
class TournamentsTab extends StatefulWidget {
  const TournamentsTab({super.key});

  @override
  State<TournamentsTab> createState() => _TournamentsTabState();
}

class _TournamentsTabState extends State<TournamentsTab> {
  late final TournamentsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TournamentsController();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabTournaments)),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.tournamentsErrorTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _controller.error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BrainjaminColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _controller.start(),
                      child: Text(l10n.tournamentsErrorRetry),
                    ),
                  ],
                ),
              ),
            );
          }

          final merged = _controller.mergedUpcomingList;
          final ended = _controller.endedTournaments;
          if (merged.isEmpty && ended.isEmpty) {
            return _EmptyNextSlot(
              title: l10n.tournamentsEmptyTitle,
              prefix: l10n.tournamentsEmptyBodyPrefix,
              targetUtc: _controller.nextSlotStartUtc,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _controller.start();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (merged.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.tournamentsActiveSectionHeader,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: BrainjaminColors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                  ...merged.map((item) {
                    VoidCallback? onTap;
                    switch (item) {
                      case TournamentListItemClassic(:final tournament):
                        onTap = () => context.pushNamed(
                          'tournament-detail',
                          pathParameters: {'slotId': tournament.slotId},
                        );
                      case TournamentListItemLive(:final tournament):
                        if (tournament.isRunning &&
                            tournament.lateJoinClosed) {
                          onTap = null;
                        } else {
                          onTap = () => context.pushNamed(
                            'live-tournament-lobby',
                            pathParameters: {'ltId': tournament.slotId},
                          );
                        }
                    }
                    return TournamentCard(
                      item: item,
                      onTap: onTap,
                    );
                  }),
                ],
                if (ended.isNotEmpty)
                  ExpansionTile(
                    initiallyExpanded: merged.isEmpty,
                    title: Text(l10n.tournamentsEndedSectionHeader),
                    children: [
                      ...ended.map(
                        (t) => TournamentCard(
                          item: TournamentListItemClassic(t),
                          onTap: () => context.pushNamed(
                            'tournament-detail',
                            pathParameters: {'slotId': t.slotId},
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Same visual pattern as [MascotEmptyState] + inline [CountdownTicker] for next slot.
class _EmptyNextSlot extends StatelessWidget {
  const _EmptyNextSlot({
    required this.title,
    required this.prefix,
    required this.targetUtc,
  });

  final String title;
  final String prefix;
  final DateTime targetUtc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: BrainjaminColors.brandOrange,
              child: Icon(Icons.psychology, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: BrainjaminColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              prefix,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 4),
            CountdownTicker(
              targetUtc: targetUtc,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: BrainjaminColors.brandOrange,
              ),
              format: CountdownTicker.formatHoursMinutes,
            ),
          ],
        ),
      ),
    );
  }
}
