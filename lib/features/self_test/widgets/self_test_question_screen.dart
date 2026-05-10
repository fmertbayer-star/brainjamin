import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/constants/app_colors.dart';
import '../data/self_test_service.dart';
import '../self_test_navigation.dart';
import '../state/self_test_controller.dart';

Future<bool> _showQuitConfirmDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.self_test_quit_title),
        content: Text(l10n.self_test_quit_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.self_test_quit_continue),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: BrainjaminColors.brandOrange,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.self_test_quit_confirm),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// One question UI + 10s timer; keyed by [currentIndex] so timer resets per question.
class SelfTestQuestionScreen extends StatelessWidget {
  const SelfTestQuestionScreen({
    super.key,
    required this.controller,
  });

  final SelfTestController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final session = controller.session;
        if (session == null ||
            controller.status == SelfTestStatus.error ||
            controller.status == SelfTestStatus.idle ||
            controller.status == SelfTestStatus.loading) {
          return const SizedBox.shrink();
        }

        final idx = controller.currentIndex.clamp(0, 24);
        final q = session.questions[idx];
        final submitting = controller.status == SelfTestStatus.submitting;
        final interceptBack = controller.status ==
                SelfTestStatus.inProgress ||
            controller.status == SelfTestStatus.submitting;

        return PopScope(
          canPop: !interceptBack,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            if (controller.status == SelfTestStatus.submitting) {
              if (context.mounted) {
                popSelfTestOrGoHome(context);
              }
              return;
            }
            if (controller.status == SelfTestStatus.inProgress) {
              final shouldQuit = await _showQuitConfirmDialog(context);
              if (shouldQuit && context.mounted) {
                controller.reset();
                popSelfTestOrGoHome(context);
              }
              return;
            }
            if (context.mounted) {
              popSelfTestOrGoHome(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (controller.status == SelfTestStatus.submitting) {
                    popSelfTestOrGoHome(context);
                  } else {
                    Navigator.maybePop(context);
                  }
                },
              ),
              title: Text(
                l10n.self_test_question_progress(idx + 1, 25),
              ),
            ),
            body: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (idx + 1) / 25,
                          backgroundColor: BrainjaminColors.onSurfaceMuted
                              .withValues(alpha: 0.2),
                          color: BrainjaminColors.brandOrange,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey<int>(idx),
                        child: _QuestionSlide(
                          controller: controller,
                          question: q,
                        ),
                      ),
                    ),
                  ],
                ),
                if (submitting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(l10n.self_test_submitting),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuestionSlide extends StatefulWidget {
  const _QuestionSlide({
    required this.controller,
    required this.question,
  });

  final SelfTestController controller;
  final SelfTestQuestion question;

  @override
  State<_QuestionSlide> createState() => _QuestionSlideState();
}

class _QuestionSlideState extends State<_QuestionSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer;
  bool _responded = false;
  bool _revealing = false;
  int? _selectedChoice;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..addStatusListener(_onTimerStatus);
    _timer.forward();
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        !_responded &&
        !_revealing) {
      _handleTimeout();
    }
  }

  void _handleTimeout() {
    if (_responded || _revealing) return;
    _responded = true;
    _timer.stop();
    widget.controller.answerCurrent(-1, 0);
    setState(() => _revealing = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _revealing = false);
      widget.controller.advance();
    });
  }

  void _onOptionTap(int optionIndex) {
    if (_responded || _revealing) return;
    _responded = true;
    _timer.stop();
    final elapsedMs = (_timer.value * 10000).round().clamp(0, 10000);
    final remainingMs = (10000 - elapsedMs).clamp(0, 10000);
    widget.controller.answerCurrent(optionIndex, remainingMs);
    setState(() {
      _revealing = true;
      _selectedChoice = optionIndex;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _revealing = false);
      widget.controller.advance();
    });
  }

  @override
  void dispose() {
    _timer.removeStatusListener(_onTimerStatus);
    _timer.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = widget.question;
    final correct = q.correctIndex;

    return AnimatedBuilder(
      animation: _timer,
      builder: (context, _) {
        final value = _timer.value.clamp(0.0, 1.0);
        final secsRemaining = ((1.0 - value) * 10).ceil().clamp(0, 10);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(_difficultyLabel(l10n, q.difficulty)),
                    side: const BorderSide(color: BrainjaminColors.brandOrange),
                    labelStyle: const TextStyle(
                      color: BrainjaminColors.brandOrangeDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Chip(
                    label: Text(q.category),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                q.questionText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: 1.0 - value,
                          strokeWidth: 6,
                          backgroundColor:
                              BrainjaminColors.onSurfaceMuted.withValues(
                                  alpha: 0.2),
                          color: BrainjaminColors.brandOrange,
                        ),
                      ),
                      Text(
                        l10n.self_test_timer_seconds(secsRemaining),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < q.options.length; i++) ...[
                _OptionTile(
                  label: q.options[i],
                  index: i,
                  revealing: _revealing,
                  selectedChoice: _selectedChoice,
                  correctIndex: correct,
                  onTap: (!_responded && !_revealing)
                      ? () => _onOptionTap(i)
                      : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.index,
    required this.revealing,
    required this.selectedChoice,
    required this.correctIndex,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool revealing;
  final int? selectedChoice;
  final int correctIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color border = BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.35);
    Color bg = Colors.white;
    Widget? trailing;

    if (revealing) {
      final isCorrect = index == correctIndex;
      final isWrongPick =
          selectedChoice != null && selectedChoice == index && index != correctIndex;
      if (isCorrect) {
        border = BrainjaminColors.success;
        bg = BrainjaminColors.success.withValues(alpha: 0.12);
        trailing = const Icon(Icons.check_circle, color: BrainjaminColors.success);
      } else if (isWrongPick) {
        border = BrainjaminColors.error;
        bg = BrainjaminColors.error.withValues(alpha: 0.12);
        trailing = const Icon(Icons.cancel, color: BrainjaminColors.error);
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 2),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
