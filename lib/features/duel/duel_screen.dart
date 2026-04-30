import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/widgets/mascot_empty_state.dart';

/// Quick Duel / duel hub — placeholders only until Sprint 3.
class DuelScreen extends StatelessWidget {
  const DuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelScreenTitle)),
      body: MascotEmptyState(
        title: l10n.duelEmptyTitle,
        body: l10n.duelEmptyBody,
      ),
    );
  }
}
