import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';
import '../self_test_navigation.dart';
import '../state/self_test_controller.dart';
import 'self_test_stats_screen.dart';

/// Self-Test session results after successful submit.
class SelfTestResultScreen extends StatelessWidget {
  const SelfTestResultScreen({
    super.key,
    required this.controller,
  });

  final SelfTestController controller;

  static const int _questionCount = 25;
  static const int _budgetMsPerQuestion = 10000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        popSelfTestOrGoHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => popSelfTestOrGoHome(context),
          ),
          title: Text(l10n.self_test_result_title),
        ),
        body: controller.result == null
            ? _buildNoResult(context, l10n)
            : _buildResult(context, l10n),
      ),
    );
  }

  Widget _buildNoResult(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.self_test_result_unavailable,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => popSelfTestOrGoHome(context),
            child: Text(l10n.self_test_result_home),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, AppLocalizations l10n) {
    final result = controller.result!;
    final correct = result.correctCount;
    final totalTimeUsedMs =
        (_questionCount * _budgetMsPerQuestion) - result.totalRemainingMs;
    final seconds = (totalTimeUsedMs / 1000).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$correct/$_questionCount',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: BrainjaminColors.brandOrange,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.self_test_result_subtitle(correct, _questionCount),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.self_test_result_time(seconds),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.self_test_result_week(result.weekKey),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BrainjaminColors.brandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    controller.reset();
                    await controller.startSession();
                  },
                  child: Text(l10n.self_test_result_play_again),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => SelfTestStatsScreen(
                          controller: controller,
                        ),
                      ),
                    );
                  },
                  child: Text(l10n.self_test_result_view_stats),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => popSelfTestOrGoHome(context),
                  child: Text(l10n.self_test_result_home),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
