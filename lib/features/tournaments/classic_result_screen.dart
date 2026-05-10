import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/countdown_ticker.dart';
import '../../core/widgets/mascot_empty_state.dart';
import 'data/classic_reveal.dart';
import 'state/classic_result_controller.dart';

class ClassicResultScreen extends StatefulWidget {
  const ClassicResultScreen({super.key, required this.slotId});

  final String slotId;

  @override
  State<ClassicResultScreen> createState() => _ClassicResultScreenState();
}

class _ClassicResultScreenState extends State<ClassicResultScreen> {
  ClassicResultController? _controller;
  bool _didRedirect = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/tournament/${widget.slotId}');
        }
      });
      return;
    }
    _controller = ClassicResultController(slotId: widget.slotId, uid: uid);
    _controller!.start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _scheduleRedirect(String path) {
    if (_didRedirect) {
      return;
    }
    _didRedirect = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = _controller;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        _didRedirect = false;
        return Scaffold(
          appBar: AppBar(title: Text('Tournament results')),
          body: switch (c.mode) {
            ClassicResultMode.loading => _buildLoading(l10n),
            ClassicResultMode.redirectToQuiz => _buildRedirecting(
                '/tournament/${widget.slotId}/quiz',
                l10n.classicResultLoadingText,
              ),
            ClassicResultMode.redirectToDetail => _buildRedirecting(
                '/tournament/${widget.slotId}',
                l10n.classicResultLoadingText,
              ),
            ClassicResultMode.error => _buildError(c, l10n),
            ClassicResultMode.pending => _buildPending(c, l10n),
            ClassicResultMode.finalized => _buildFinalized(c, l10n),
          },
        );
      },
    );
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(l10n.classicResultLoadingText),
        ],
      ),
    );
  }

  Widget _buildRedirecting(String to, String message) {
    _scheduleRedirect(to);
    return Center(child: Text(message));
  }

  Widget _buildError(ClassicResultController c, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MascotEmptyState(
            title: l10n.classicResultErrorTitle,
            body: c.error ?? l10n.classicQuizErrorGeneric,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: c.start,
            child: Text(l10n.classicResultErrorRetry),
          ),
          TextButton(
            onPressed: () => context.go('/tournament/${widget.slotId}'),
            child: Text(l10n.classicResultErrorBack),
          ),
        ],
      ),
    );
  }

  Widget _buildPending(ClassicResultController c, AppLocalizations l10n) {
    final session = c.session!;
    final t = c.tournament;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: BrainjaminColors.brandOrange,
              child: Icon(Icons.psychology, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.classicResultPendingScore(session.correctCount ?? 0),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.classicResultPendingBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrainjaminColors.onSurfaceMuted,
                  ),
            ),
            if (t != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.classicResultPendingEndsIn,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: BrainjaminColors.onSurfaceMuted,
                    ),
              ),
              const SizedBox(height: 4),
              CountdownTicker(
                targetUtc: t.endsAt,
                format: CountdownTicker.formatHoursMinutes,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BrainjaminColors.brandOrangeDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go('/tournament/${widget.slotId}'),
              child: Text(l10n.classicResultPendingBackCta),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalized(ClassicResultController c, AppLocalizations l10n) {
    final reveal = c.reveal;
    if (reveal == null) {
      return _buildLoading(l10n);
    }
    final meta = reveal.sessionMeta;
    final rank = meta.rank;
    final totalParticipants = reveal.leaderboardSnippet?.totalParticipants ?? 0;
    final mascotIcon = _mascotForRank(rank);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: BrainjaminColors.brandOrange,
                  child: Icon(mascotIcon, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 12),
                if (rank != null)
                  Text(
                    l10n.classicResultFinalizedRank(rank, totalParticipants),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                const SizedBox(height: 8),
                Text(
                  l10n.classicResultFinalizedScore(meta.correctCount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  meta.xpAwarded != null ?
                      l10n.classicResultFinalizedXpEarned(meta.xpAwarded!) :
                      l10n.classicResultFinalizedXpPending,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: BrainjaminColors.brandOrangeDark,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (reveal.leaderboardSnippet != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.classicResultFinalizedTop10Header,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...reveal.leaderboardSnippet!.top10.map((e) {
            final highlighted = rank != null && e.rank == rank;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: highlighted ?
                      BrainjaminColors.brandOrange :
                      BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.25),
                ),
                color: highlighted ?
                    BrainjaminColors.brandOrange.withValues(alpha: 0.08) :
                    Colors.transparent,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('#${e.rank}'),
                  ),
                  Expanded(child: Text(e.displayName)),
                  Text(l10n.classicResultFinalizedTop10Entry(e.correctCount)),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.classicResultFinalizedAnswersHeader,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ...reveal.questions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value;
          return _QuestionReviewTile(
            number: i + 1,
            question: q,
            title: l10n.classicResultFinalizedQuestionTitle(
              i + 1,
              q.category,
              q.difficulty,
            ),
          );
        }),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.classicResultFinalizedBackCta),
        ),
      ],
    );
  }

  IconData _mascotForRank(int? rank) {
    if (rank != null && rank >= 1 && rank <= 10) {
      return Icons.celebration;
    }
    if (rank != null && rank >= 11 && rank <= 50) {
      return Icons.psychology;
    }
    return Icons.psychology;
  }
}

class _QuestionReviewTile extends StatelessWidget {
  const _QuestionReviewTile({
    required this.number,
    required this.question,
    required this.title,
  });

  final int number;
  final ClassicRevealQuestion question;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(question.question),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (var i = 0; i < question.options.length; i++) ...[
            _AnsweredOptionTile(
              text: question.options[i],
              isCorrectOption: question.correctIndex == i,
              isWrongSelection:
                  question.userAnswerIndex == i && question.correctIndex != i,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AnsweredOptionTile extends StatelessWidget {
  const _AnsweredOptionTile({
    required this.text,
    required this.isCorrectOption,
    required this.isWrongSelection,
  });

  final String text;
  final bool isCorrectOption;
  final bool isWrongSelection;

  @override
  Widget build(BuildContext context) {
    Color border = BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.3);
    Color background = Colors.white;
    IconData? icon;
    Color iconColor = BrainjaminColors.onSurfaceMuted;
    if (isCorrectOption) {
      border = BrainjaminColors.success;
      background = BrainjaminColors.success.withValues(alpha: 0.10);
      icon = Icons.check_circle;
      iconColor = BrainjaminColors.success;
    } else if (isWrongSelection) {
      border = BrainjaminColors.error;
      background = BrainjaminColors.error.withValues(alpha: 0.10);
      icon = Icons.cancel;
      iconColor = BrainjaminColors.error;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        color: background,
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (icon != null) Icon(icon, color: iconColor),
        ],
      ),
    );
  }
}
