import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Placeholder deep-link stem (V2 universal links).
const String kArenaInviteDeepLinkStem = 'https://brainjamin.com/arena/';

class ArenaInviteShareScreen extends StatelessWidget {
  const ArenaInviteShareScreen({super.key});

  Future<void> _share(BuildContext context, String bareCode) async {
    final l10n = AppLocalizations.of(context);
    final text = l10n.arena_invite_share_message(bareCode);
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qp = GoRouterState.of(context).uri.queryParameters;
    final arenaId = qp['arenaId']?.trim();
    final inviteCode = qp['inviteCode']?.trim();

    if (arenaId == null ||
        arenaId.isEmpty ||
        inviteCode == null ||
        inviteCode.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_invite_share_title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.arena_invite_missing_params),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/arena'),
                child: Text(l10n.arena_result_home),
              ),
            ],
          ),
        ),
      );
    }

    final bareCode = inviteCode.trim().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.arena_invite_share_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              'BJ-$bareCode',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              kArenaInviteDeepLinkStem,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: l10n.arena_lobby_copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: bareCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.arena_lobby_copy)),
                  );
                }
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _share(context, bareCode),
              child: Text(l10n.arena_invite_share_action),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final uri = Uri(
                  path: '/arena/lobby',
                  queryParameters: {'arenaId': arenaId},
                );
                context.go(uri.toString());
              },
              child: Text(l10n.arena_invite_continue_lobby),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/arena'),
              child: Text(l10n.arena_result_home),
            ),
          ],
        ),
      ),
    );
  }
}
