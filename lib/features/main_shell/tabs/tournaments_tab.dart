import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/widgets/mascot_empty_state.dart';

/// Tournaments tab — listing ships in Sprint 4.
class TournamentsTab extends StatelessWidget {
  const TournamentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabTournaments)),
      body: MascotEmptyState(
        title: l10n.tournamentsEmptyTitle,
        body: l10n.tournamentsEmptyBody,
      ),
    );
  }
}
