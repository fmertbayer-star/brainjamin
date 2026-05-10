import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/mascot_empty_state.dart';
import '../data/arena_models.dart';
import '../data/arena_service.dart';

class ArenaResultScreen extends StatelessWidget {
  const ArenaResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

    final arenaService = ArenaService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arena_result_title)),
      body: StreamBuilder<ArenaDoc?>(
        stream: arenaService.listenToArena(arenaId),
        builder: (context, arenaSnap) {
          final arena = arenaSnap.data;
          if (!arenaSnap.hasData && arenaSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (arena == null) {
            return Center(child: Text(l10n.arena_join_error_not_found));
          }

          return StreamBuilder<ArenaParticipant?>(
            stream: arenaService.listenToMyParticipant(arenaId),
            builder: (context, meSnap) {
              final me = meSnap.data;

              return StreamBuilder<List<ArenaLeaderboardEntry>>(
                stream: arenaService.listenToArenaLeaderboard(arenaId),
                builder: (context, lbSnap) {
                  final rows = lbSnap.data ?? [];
                  final ended = arena.status == 'ended';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (me?.xpAwarded != null && me!.xpAwarded! > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Chip(
                                  label: Text(l10n.arena_result_xp_earned(me.xpAwarded!)),
                                  backgroundColor:
                                      BrainjaminColors.brandOrange.withValues(alpha: 0.15),
                                ),
                              ),
                            if (!ended) ...[
                              MascotEmptyState(
                                title: l10n.arena_result_waiting,
                                body: me?.correctCount != null && me?.score != null
                                    ? '${me!.correctCount}/10 · ${me.score!.toStringAsFixed(3)}'
                                    : '',
                              ),
                              if (me?.rank != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    l10n.arena_result_your_rank(me!.rank!),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ] else ...[
                              if (me?.rank != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    l10n.arena_result_your_rank(me!.rank!),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ...rows.map((e) {
                                final mine = uid != null && e.uid == uid;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: mine
                                            ? BrainjaminColors.brandOrange
                                            : Colors.transparent,
                                        width: mine ? 2 : 0,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${e.rank}'),
                                      ),
                                      title: Text(e.displayName),
                                      subtitle: Text(
                                        '${e.correctCount}/10 · ${e.score.toStringAsFixed(3)}',
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              onPressed: () => context.go('/arena/create'),
                              child: Text(l10n.arena_result_new_arena_cta),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => context.go('/'),
                              child: Text(l10n.arena_result_home),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
