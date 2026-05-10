import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Placeholder duel deep-link stem (V2 universal links). Share text carries the invite code prominently.
const String kDuelInviteDeepLinkStem = 'https://brainjamin.com/duel/';

class DuelInviteShareScreen extends StatelessWidget {
  const DuelInviteShareScreen({super.key});

  Future<void> _share(BuildContext context, String codeForMessage) async {
    final l10n = AppLocalizations.of(context);
    final text = l10n.duelInviteShareMessage(codeForMessage);
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qp = GoRouterState.of(context).uri.queryParameters;
    final duelId = qp['duelId']?.trim();
    final inviteCode = qp['inviteCode']?.trim();

    if (duelId == null ||
        duelId.isEmpty ||
        inviteCode == null ||
        inviteCode.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.duelInviteShareTitle)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.duelInviteShareMissingParams),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.duelResultBackHome),
              ),
            ],
          ),
        ),
      );
    }

    final bareCode = inviteCode.trim().toUpperCase();
    final codeForShare = bareCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.duelInviteShareTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.duelInviteShareSubtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SelectableText(
              bareCode,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              kDuelInviteDeepLinkStem,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.duelInviteShareDeepLinkFootnote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: l10n.duelInviteShareCopyTooltip,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: bareCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.duelInviteShareCodeCopied)),
                  );
                }
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _share(context, codeForShare),
              child: Text(l10n.duelInviteShareShareButton),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final uri = Uri(
                  path: '/duel/quiz',
                  queryParameters: {'duelId': duelId},
                );
                context.push(uri.toString());
              },
              child: Text(l10n.duelInviteSharePlayNow),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(l10n.duelResultBackHome),
            ),
          ],
        ),
      ),
    );
  }
}
