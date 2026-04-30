import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/widgets/mascot_empty_state.dart';

/// Self-Test flow root — placeholders only until Sprint 2.
class SelfTestScreen extends StatelessWidget {
  const SelfTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.selfTestScreenTitle)),
      body: MascotEmptyState(
        title: l10n.selfTestEmptyTitle,
        body: l10n.selfTestEmptyBody,
      ),
    );
  }
}
