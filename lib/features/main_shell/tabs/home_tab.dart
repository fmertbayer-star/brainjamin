import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../daily/data/daily_question_service.dart';
import '../../daily/state/daily_question_controller.dart';
import '../../daily/widgets/daily_question_card.dart';
import '../../home/widgets/active_arenas_card.dart';
import '../../home/widgets/next_live_countdown_card.dart';
import '../../home/widgets/quick_duel_card.dart';
import '../../home/widgets/self_test_entry_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onNavigateToTab});

  /// Switches MainShell tab by index — used for deeper Home affordances without router routes.
  final void Function(int index) onNavigateToTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final DailyQuestionController _dailyController;

  @override
  void initState() {
    super.initState();
    _dailyController = DailyQuestionController(service: DailyQuestionService());
    _dailyController.init();
  }

  @override
  void dispose() {
    _dailyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabHome)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            DailyQuestionCard(
              controller: _dailyController,
              onTap: () async {
                await context.push('/daily', extra: _dailyController);
                if (!mounted) {
                  return;
                }
                await _dailyController.init();
              },
            ),
            SelfTestEntryCard(
              title: l10n.homeCardSelfTestTitle,
              body: l10n.homeCardSelfTestBody,
              onTap: () => context.push('/self-test'),
            ),
            QuickDuelCard(
              title: l10n.homeCardQuickDuelTitle,
              body: l10n.homeCardQuickDuelBody,
              onTap: () => context.push('/duel'),
            ),
            ActiveArenasCard(
              title: l10n.homeCardActiveArenasTitle,
              body: l10n.homeCardActiveArenasBody,
              onTap: () => context.push('/arena'),
            ),
            NextLiveCountdownCard(
              title: l10n.homeCardNextLiveTitle,
              body: l10n.homeCardNextLiveBody,
              onTap: () => widget.onNavigateToTab(1),
            ),
          ],
        ),
      ),
    );
  }
}
