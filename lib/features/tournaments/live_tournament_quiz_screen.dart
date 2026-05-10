import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import 'data/live_question_data.dart';
import 'state/live_quiz_controller.dart';

/// Live tournament quiz — server-driven pacing; mascot-free (BRAINJAMIN § DESIGN).
class LiveTournamentQuizScreen extends StatefulWidget {
  const LiveTournamentQuizScreen({super.key, required this.ltId});

  final String ltId;

  @override
  State<LiveTournamentQuizScreen> createState() =>
      _LiveTournamentQuizScreenState();
}

class _LiveTournamentQuizScreenState extends State<LiveTournamentQuizScreen> {
  LiveQuizController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = LiveQuizController(
      ltId: widget.ltId,
      onSubmittedSuccess: _navigateToResult,
      onTournamentAborted: _abortToMain,
    );
    _controller!.addListener(_onCtrl);
  }

  void _onCtrl() {
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.replaceNamed(
        'live-tournament-result',
        pathParameters: {'ltId': widget.ltId},
      );
    });
  }

  void _abortToMain(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.go('/');
    });
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Leave tournament?'),
          content: const Text(
            'Leaving early — Brainjamin will still log your answers. Sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onCtrl);
    _controller?.dispose();
    super.dispose();
  }

  int _answerSecondsCeil(int ms) {
    if (ms <= 0) {
      return 0;
    }
    return max(1, (ms + 999) ~/ 1000);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _controller;
    if (c == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _confirmLeave();
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _confirmLeave,
                        child: const Text('Leave'),
                      ),
                    ),
                    _buildStatusBar(context, theme, c),
                    const SizedBox(height: 16),
                    Expanded(child: _buildMainBody(context, theme, c)),
                    const SizedBox(height: 12),
                    Text(
                      'Players: ${c.liveDoc?.totalParticipants ?? 0}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BrainjaminColors.onSurfaceMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (c.phase == LiveQuizPhase.submitting) _submittingOverlay(theme),
            if (c.phase == LiveQuizPhase.error) _errorOverlay(context, theme, c),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    BuildContext context,
    ThemeData theme,
    LiveQuizController c,
  ) {
    final cq = c.currentQuestion?.qIndex ?? c.liveDoc?.currentQuestion;
    final qLabel = cq != null ? 'Question ${cq + 1} of 20' : 'Question —';

    Widget right;
    if (c.phase == LiveQuizPhase.answering) {
      final sec = _answerSecondsCeil(c.answerCountdownMs);
      right = Text(
        '${sec}s',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: BrainjaminColors.brandOrange,
        ),
      );
    } else if (c.phase == LiveQuizPhase.revealing) {
      right = Text(
        'Reveal',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: BrainjaminColors.onSurfaceMuted,
        ),
      );
    } else {
      right = const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            qLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        right,
      ],
    );
  }

  Widget _buildMainBody(
    BuildContext context,
    ThemeData theme,
    LiveQuizController c,
  ) {
    switch (c.phase) {
      case LiveQuizPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case LiveQuizPhase.awaitingQuestion:
        return Center(
          child: Text(
            'Waiting for the next question…',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      case LiveQuizPhase.answering:
      case LiveQuizPhase.revealing:
        final q = c.currentQuestion;
        if (q == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _questionPanel(context, theme, c, q);
      case LiveQuizPhase.submitting:
        return const SizedBox.shrink();
      case LiveQuizPhase.submitted:
        return Center(
          child: Text(
            'Answers saved — loading results…',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      case LiveQuizPhase.error:
        return const SizedBox.shrink();
    }
  }

  Widget _questionPanel(
    BuildContext context,
    ThemeData theme,
    LiveQuizController c,
    LiveQuestionData q,
  ) {
    final text = q.questionText;
    final options = q.options;
    final correct = q.correctIndex;
    final qIndex = q.qIndex;

    final selected = c.localSelectionsSnapshot[qIndex];
    final revealing = c.phase == LiveQuizPhase.revealing;

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              text,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ListView.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final label = i < options.length ? options[i] : '';
              return _OptionButton(
                label: label,
                index: i,
                selected: selected == i,
                revealing: revealing,
                correctIndex: correct,
                userSelected: selected,
                onTap: () => c.selectOption(i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _submittingOverlay(ThemeData theme) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Submitting your answers…',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorOverlay(
    BuildContext context,
    ThemeData theme,
    LiveQuizController c,
  ) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Couldn't submit your answers — tap to retry",
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (c.submitError != null) ...[
                const SizedBox(height: 8),
                Text(
                  c.submitError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => unawaited(c.retrySubmit()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.index,
    required this.selected,
    required this.revealing,
    required this.correctIndex,
    required this.userSelected,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool selected;
  final bool revealing;
  final int? correctIndex;
  final int? userSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bg = BrainjaminColors.brandOrange.withValues(alpha: 0.08);
    Color border = BrainjaminColors.brandOrange.withValues(alpha: 0.35);
    double opacity = 1;

    if (revealing && correctIndex != null) {
      final isCorrect = index == correctIndex;
      final isWrongPick = userSelected == index && userSelected != correctIndex;

      if (isCorrect) {
        bg = BrainjaminColors.success.withValues(alpha: 0.35);
        border = BrainjaminColors.success;
      } else if (isWrongPick) {
        bg = Colors.red.withValues(alpha: 0.35);
        border = Colors.red.shade700;
      } else {
        opacity = 0.45;
        bg = BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.08);
        border = BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.2);
      }
    } else if (selected) {
      bg = BrainjaminColors.brandOrange.withValues(alpha: 0.22);
      border = BrainjaminColors.brandOrange;
    }

    return Opacity(
      opacity: opacity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: revealing ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: selected && !revealing ? 2 : 1),
            ),
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
