import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/widgets/mascot_empty_state.dart';

/// Leaderboard tab — sign-in CTA lands in Sprint 5.
class LeaderboardTab extends StatelessWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabLeaderboard)),
      body: MascotEmptyState(
        title: l10n.leaderboardEmptyTitle,
        body: l10n.leaderboardEmptyBody,
      ),
    );
  }
}
