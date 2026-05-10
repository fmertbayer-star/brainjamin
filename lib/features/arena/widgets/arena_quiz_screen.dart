import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mascot_empty_state.dart';
import '../data/arena_models.dart';
import '../data/arena_service.dart';
import 'arena_overflow_menu.dart';
import 'arena_quiz_controller.dart';

class ArenaQuizScreen extends StatelessWidget {
  const ArenaQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final arenaId = GoRouterState.of(context).uri.queryParameters['arenaId']?.trim();
    if (arenaId == null || arenaId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_quiz_title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.arena_invite_missing_params),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/arena'),
                child: Text(l10n.arena_quiz_error_back),
              ),
            ],
          ),
        ),
      );
    }

    final arenaService = ArenaService();
    return StreamBuilder<ArenaDoc?>(
      stream: arenaService.listenToArena(arenaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.arena_quiz_title)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l10n.arena_quiz_loading),
                ],
              ),
            ),
          );
        }
        final arena = snap.data;
        if (arena == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.arena_quiz_title)),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.arena_join_error_not_found),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/arena'),
                    child: Text(l10n.arena_quiz_error_back),
                  ),
                ],
              ),
            ),
          );
        }
        if (arena.mode == 'battle') {
          // TODO: Battle Arena (Sprint 3.5d)
          return Scaffold(
            appBar: AppBar(title: Text(l10n.arena_quiz_title)),
            body: MascotEmptyState(
              title: l10n.arena_quiz_battle_soon_title,
              body: l10n.arena_quiz_battle_soon_body,
            ),
          );
        }
        return _ArenaListQuizBody(arenaId: arenaId);
      },
    );
  }
}

class _ArenaListQuizBody extends StatefulWidget {
  const _ArenaListQuizBody({required this.arenaId});

  final String arenaId;

  @override
  State<_ArenaListQuizBody> createState() => _ArenaListQuizBodyState();
}

class _ArenaListQuizBodyState extends State<_ArenaListQuizBody>
    with SingleTickerProviderStateMixin {
  static const int _questionTimeMs = 15000;

  final ArenaQuizController _controller = ArenaQuizController();
  late final AnimationController _timer;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _questionTimeMs),
    )..addStatusListener(_onTimerStatus);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _controller.load(widget.arenaId);
    if (!mounted) return;
    if (_controller.status == ArenaQuizStatus.ready) {
      _startQuestionTimer();
    }
  }

  void _startQuestionTimer() {
    _timer
      ..stop()
      ..reset()
      ..forward();
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!_quizInProgress) return;
    if (_controller.revealing) return;
    _recordAndReveal(-1);
  }

  bool get _quizInProgress {
    final qs = _controller.questions;
    return _controller.status == ArenaQuizStatus.ready &&
        qs != null &&
        qs.isNotEmpty &&
        _controller.currentIndex < qs.length;
  }

  void _recordAndReveal(int selectedOption) {
    if (!_quizInProgress) return;
    if (_controller.revealing) return;
    _timer.stop();
    final elapsedMs =
        (_timer.value * _questionTimeMs).round().clamp(0, _questionTimeMs);
    _controller.recordReveal(
      selectedOption: selectedOption,
      elapsedMs: elapsedMs,
    );
    Future<void>.delayed(const Duration(milliseconds: 600), _afterReveal);
  }

  Future<void> _afterReveal() async {
    if (!mounted) return;
    await _controller.advanceOrSubmit(widget.arenaId);
    if (!mounted) return;
    if (_controller.status == ArenaQuizStatus.submitted) {
      final uri = Uri(
        path: '/arena/result',
        queryParameters: {'arenaId': widget.arenaId},
      );
      context.go(uri.toString());
      return;
    }
    if (_controller.status == ArenaQuizStatus.error) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.arena_quiz_submit_error}\n${_controller.error ?? ''}',
          ),
          action: SnackBarAction(
            label: l10n.arena_quiz_retry,
            onPressed: _retrySubmit,
          ),
        ),
      );
      return;
    }
    if (_controller.status == ArenaQuizStatus.ready && !_controller.revealing) {
      _startQuestionTimer();
    }
  }

  Future<void> _retrySubmit() async {
    await _controller.submit(widget.arenaId);
    if (!mounted) return;
    if (_controller.status == ArenaQuizStatus.submitted) {
      context.go(
        Uri(
          path: '/arena/result',
          queryParameters: {'arenaId': widget.arenaId},
        ).toString(),
      );
    }
  }

  Future<bool> _showQuitConfirmDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.duelQuizQuitTitle),
          content: Text(l10n.duelQuizQuitBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.duelQuizQuitStay),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.duelQuizQuitConfirm),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _timer.removeStatusListener(_onTimerStatus);
    _timer.dispose();
    _controller.dispose();
    super.dispose();
  }

  ButtonStyle? _buildOptionStyle(
    int index,
    ArenaQuestionView question,
  ) {
    if (!_controller.revealing) return null;
    final correctIndex = question.correctIndex;
    Color? bgColor;
    final sel = _controller.selectedOption;
    final isSelected = sel == index;
    if (correctIndex != null && correctIndex == index) {
      bgColor = Colors.green;
    } else if (correctIndex == null && isSelected && sel != -1) {
      bgColor = Colors.green;
    } else if (sel == -1) {
      bgColor = null;
    } else if (isSelected) {
      bgColor = Colors.red;
    } else {
      bgColor = null;
    }
    if (bgColor == null) return null;
    return ElevatedButton.styleFrom(backgroundColor: bgColor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_controller.status == ArenaQuizStatus.loading ||
        _controller.status == ArenaQuizStatus.idle) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_quiz_title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.arena_quiz_loading),
            ],
          ),
        ),
      );
    }

    if (_controller.status == ArenaQuizStatus.error &&
        _controller.questions == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_quiz_title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${l10n.arena_quiz_submit_error}\n${_controller.error ?? ''}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/arena'),
                child: Text(l10n.arena_quiz_error_back),
              ),
            ],
          ),
        ),
      );
    }

    final qs = _controller.questions!;
    final idx = _controller.currentIndex;
    final question = qs[idx];
    final interceptBack =
        _quizInProgress && _controller.status != ArenaQuizStatus.submitting;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.arena_quiz_progress(idx + 1, qs.length)),
        actions: [
          ArenaOverflowMenu(questionId: question.reportQuestionId),
        ],
      ),
      body: PopScope(
        canPop: !interceptBack,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || !interceptBack) return;
          final shouldQuit = await _showQuitConfirmDialog();
          if (shouldQuit && context.mounted) {
            context.go('/arena');
          }
        },
        child: AnimatedBuilder(
          animation: _timer,
          builder: (context, _) {
            final value = _timer.value.clamp(0.0, 1.0);
            final seconds = ((1.0 - value) * 15).ceil().clamp(0, 15);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Chip(label: Text(l10n.arena_quiz_timer(seconds))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < question.options.length; i++) ...[
                    ElevatedButton(
                      style: _buildOptionStyle(i, question),
                      onPressed: (_controller.revealing ||
                              _controller.status == ArenaQuizStatus.submitting)
                          ? null
                          : () => _recordAndReveal(i),
                      child: Text(question.options[i]),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_controller.status == ArenaQuizStatus.submitting) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(l10n.arena_quiz_submitting),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
