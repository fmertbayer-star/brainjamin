import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';
import '../data/self_test_service.dart';
import '../self_test_navigation.dart';
import '../state/self_test_controller.dart';

/// Client-side session statistics (same data as result screen; pushed detail page).
class SelfTestStatsScreen extends StatelessWidget {
  const SelfTestStatsScreen({
    super.key,
    required this.controller,
  });

  final SelfTestController controller;

  static const int _n = 25;
  static const int _budgetMs = 10000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = controller.session;
    final result = controller.result;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
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
          title: Text(l10n.self_test_stats_title),
        ),
        body: session == null || result == null
            ? _buildMissingData(context, l10n)
            : _buildStats(context, l10n, session),
      ),
    );
  }

  Widget _buildMissingData(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.self_test_stats_no_session,
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

  Widget _buildStats(
    BuildContext context,
    AppLocalizations l10n,
    SelfTestSessionData session,
  ) {
    final questions = session.questions;
    final answers = controller.answers;
    final remainingMs = controller.perQuestionRemainingMs;

    int isCorrect(int i) {
      final a = answers[i];
      if (a == null || a < 0) {
        return 0;
      }
      return a == questions[i].correctIndex ? 1 : 0;
    }

    int correctInDifficulty(int d) {
      var sum = 0;
      for (var i = 0; i < _n; i++) {
        if (questions[i].difficulty == d) {
          sum += isCorrect(i);
        }
      }
      return sum;
    }

    final theme = Theme.of(context);
    final surfaceVariant = theme.colorScheme.surfaceContainerHighest;

    final categoryTotals = <String, int>{};
    final categoryCorrect = <String, int>{};
    for (var i = 0; i < _n; i++) {
      final cat = questions[i].category;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + 1;
      categoryCorrect[cat] = (categoryCorrect[cat] ?? 0) + isCorrect(i);
    }

    final categoryEntries = categoryTotals.entries
        .where((e) => e.value >= 2)
        .map(
          (e) => MapEntry(
            e.key,
            (
              correct: categoryCorrect[e.key] ?? 0,
              total: e.value,
            ),
          ),
        )
        .toList()
      ..sort((a, b) {
        final t = b.value.total.compareTo(a.value.total);
        if (t != 0) {
          return t;
        }
        final ra = a.value.correct / a.value.total;
        final rb = b.value.correct / b.value.total;
        return rb.compareTo(ra);
      });

    var totalTimeSumMs = 0;
    var correctTimeSumMs = 0;
    var correctCountForSpeed = 0;
    var wrongTimeSumMs = 0;
    var wrongCountForSpeed = 0;
    for (var i = 0; i < _n; i++) {
      final used = _budgetMs - remainingMs[i].clamp(0, _budgetMs);
      totalTimeSumMs += used;
      if (isCorrect(i) == 1) {
        correctTimeSumMs += used;
        correctCountForSpeed++;
      } else {
        wrongTimeSumMs += used;
        wrongCountForSpeed++;
      }
    }

    final avgSec = (totalTimeSumMs / _n / 1000).round();
    final showSpeedSplit =
        correctCountForSpeed > 0 && wrongCountForSpeed > 0;
    final avgCorrectSec = showSpeedSplit
        ? (correctTimeSumMs / correctCountForSpeed / 1000).round()
        : 0;
    final avgWrongSec = showSpeedSplit
        ? (wrongTimeSumMs / wrongCountForSpeed / 1000).round()
        : 0;

    var minRatio = 2.0;
    var weakestD = 1;
    for (var d = 1; d <= 5; d++) {
      final c = correctInDifficulty(d);
      final r = c / 5.0;
      if (r < minRatio - 1e-9) {
        minRatio = r;
        weakestD = d;
      } else if ((r - minRatio).abs() < 1e-9 && d > weakestD) {
        weakestD = d;
      }
    }
    final weakestCorrect = correctInDifficulty(weakestD);
    final weakestPct = (weakestCorrect * 100 / 5).round();
    final insightStrong = weakestPct >= 80;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.self_test_stats_difficulty_heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var d = 1; d <= 5; d++) ...[
            if (d > 1) const SizedBox(height: 12),
            _DifficultyRow(
              label: _difficultyLabel(l10n, d),
              correct: correctInDifficulty(d),
              surfaceVariant: surfaceVariant,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.self_test_stats_category_heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (categoryEntries.isEmpty)
            Text(
              l10n.self_test_stats_category_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < categoryEntries.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _CategoryRow(
                category: categoryEntries[i].key,
                correct: categoryEntries[i].value.correct,
                total: categoryEntries[i].value.total,
              ),
            ],
          const SizedBox(height: 24),
          Text(
            l10n.self_test_stats_speed_heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.self_test_stats_avg_time(avgSec),
            style: theme.textTheme.bodyLarge,
          ),
          if (showSpeedSplit) ...[
            const SizedBox(height: 8),
            Text(
              l10n.self_test_stats_avg_correct(avgCorrectSec),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.self_test_stats_avg_wrong(avgWrongSec),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.self_test_stats_insight_heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            insightStrong
                ? l10n.self_test_stats_insight_strong
                : l10n.self_test_stats_insight_weakest(
                    _difficultyLabel(l10n, weakestD),
                    weakestPct,
                  ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.self_test_stats_back_to_results),
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(AppLocalizations l10n, int d) {
    switch (d) {
      case 1:
        return l10n.self_test_difficulty_1;
      case 2:
        return l10n.self_test_difficulty_2;
      case 3:
        return l10n.self_test_difficulty_3;
      case 4:
        return l10n.self_test_difficulty_4;
      case 5:
        return l10n.self_test_difficulty_5;
      default:
        return '';
    }
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({
    required this.label,
    required this.correct,
    required this.surfaceVariant,
  });

  final String label;
  final int correct;
  final Color surfaceVariant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: correct / 5.0,
              minHeight: 8,
              backgroundColor: surfaceVariant,
              color: BrainjaminColors.brandOrange,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$correct/5',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.correct,
    required this.total,
  });

  final String category;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0 : ((correct * 100) / total).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            category,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Text(
          '$correct/$total',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '$pct%',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}
