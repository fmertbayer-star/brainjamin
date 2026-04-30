import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/widgets/mascot_empty_state.dart';

/// Arena hub — placeholders only until Sprint 3.
class ArenaScreen extends StatelessWidget {
  const ArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arenaScreenTitle)),
      body: MascotEmptyState(
        title: l10n.arenaEmptyTitle,
        body: l10n.arenaEmptyBody,
      ),
    );
  }
}
