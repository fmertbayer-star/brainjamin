import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Arena hub — create / join entry points (List mode UI Sprint 3.5c).
class ArenaScreen extends StatelessWidget {
  const ArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arenaScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => context.push('/arena/create'),
              child: Text(l10n.arena_screen_create_cta),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/arena/join'),
              child: Text(l10n.arena_screen_join_cta),
            ),
          ],
        ),
      ),
    );
  }
}
