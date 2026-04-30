import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../home/widgets/active_arenas_card.dart';
import '../../home/widgets/daily_question_card.dart';
import '../../home/widgets/next_live_countdown_card.dart';
import '../../home/widgets/quick_duel_card.dart';
import '../../home/widgets/self_test_entry_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onNavigateToTab});

  /// Switches MainShell tab by index — used for deeper Home affordances without router routes.
  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabHome)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            // TODO(sprint-2): wire daily question
            DailyQuestionCard(
              title: l10n.homeCardDailyTitle,
              body: l10n.homeCardDailyBody,
              onTap: () {},
            ),
            SelfTestEntryCard(
              title: l10n.homeCardSelfTestTitle,
              body: l10n.homeCardSelfTestBody,
              onTap: () => context.go('/self-test'),
            ),
            QuickDuelCard(
              title: l10n.homeCardQuickDuelTitle,
              body: l10n.homeCardQuickDuelBody,
              onTap: () => context.go('/duel'),
            ),
            ActiveArenasCard(
              title: l10n.homeCardActiveArenasTitle,
              body: l10n.homeCardActiveArenasBody,
              onTap: () => context.go('/arena'),
            ),
            NextLiveCountdownCard(
              title: l10n.homeCardNextLiveTitle,
              body: l10n.homeCardNextLiveBody,
              onTap: () => onNavigateToTab(1),
            ),
          ],
        ),
      ),
    );
  }
}
