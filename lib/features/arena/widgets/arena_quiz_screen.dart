import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
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
    final arenaId =
        GoRouterState.of(context).uri.queryParameters['arenaId']?.trim();
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

class _ArenaListQuizBodyState extends State<_ArenaListQuizBody> {
  ArenaQuizController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = ArenaQuizController(
      arenaId: widget.arenaId,
      onSubmittedSuccess: _navigateToResult,
      onArenaAborted: _abortToArenaHome,
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
      context.go(
        Uri(
          path: '/arena/result',
          queryParameters: {'arenaId': widget.arenaId},
        ).toString(),
      );
    });
  }

  void _abortToArenaHome(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.go('/arena');
    });
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.duelQuizQuitConfirm),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      context.go('/arena');
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

  int _revealSecondsCeil(int ms) {
    if (ms <= 0) {
      return 0;
    }
    return max(1, (ms + 999) ~/ 1000);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = _controller;
    if (c == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final qForReport = c.currentQuestion?.reportQuestionId ?? 'arena_unknown';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.arena_quiz_title),
          actions: [
            ArenaOverflowMenu(questionId: qForReport),
          ],
        ),
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
                        child: Text(l10n.duelQuizQuitConfirm),
                      ),
                    ),
                    _buildStatusBar(context, theme, l10n, c),
                    const SizedBox(height: 16),
                    Expanded(child: _buildMainBody(context, theme, l10n, c)),
                    const SizedBox(height: 12),
                    Text(
                      l10n.arena_lobby_participants(c.arenaDoc?.participantCount ?? 0),
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
            if (c.phase == ArenaQuizPhase.submitting) _submittingOverlay(theme, l10n),
            if (c.phase == ArenaQuizPhase.error) _errorOverlay(context, theme, l10n, c),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ArenaQuizController c,
  ) {
    final cq = c.currentQuestion?.qIndex ?? c.arenaDoc?.currentQuestion;
    final qLabel = cq != null
        ? l10n.arena_quiz_progress(cq + 1, ArenaQuizController.kQuestionCount)
        : l10n.arena_quiz_loading;

    Widget right;
    if (c.phase == ArenaQuizPhase.answering) {
      final sec = _answerSecondsCeil(c.answerCountdownMs);
      right = Text(
        l10n.arena_quiz_timer(sec),
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: BrainjaminColors.brandOrange,
        ),
      );
    } else if (c.phase == ArenaQuizPhase.revealing) {
      right = Text(
        l10n.arena_quiz_reveal_label,
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
    AppLocalizations l10n,
    ArenaQuizController c,
  ) {
    switch (c.phase) {
      case ArenaQuizPhase.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.arena_quiz_loading),
            ],
          ),
        );
      case ArenaQuizPhase.awaitingStart:
        return MascotEmptyState(
          title: l10n.arena_quiz_awaiting_start_title,
          body: l10n.arena_quiz_awaiting_start_body,
        );
      case ArenaQuizPhase.answering:
      case ArenaQuizPhase.revealing:
        final q = c.currentQuestion;
        if (q == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.arena_quiz_loading),
              ],
            ),
          );
        }
        return _questionPanel(context, theme, l10n, c, q);
      case ArenaQuizPhase.submitting:
        return const SizedBox.shrink();
      case ArenaQuizPhase.submitted:
        return Center(
          child: Text(
            l10n.arena_quiz_submitted_body,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      case ArenaQuizPhase.error:
        return const SizedBox.shrink();
    }
  }

  Widget _questionPanel(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ArenaQuizController c,
    ArenaQuestionView q,
  ) {
    final text = q.question;
    final options = q.options;
    final correct = q.correctIndex;
    final qIndex = q.qIndex;

    final selected = c.localSelectionsSnapshot[qIndex];
    final revealing = c.phase == ArenaQuizPhase.revealing;
    final answered = selected != null;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            text,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
          if (c.phase == ArenaQuizPhase.answering && answered) ...[
            const SizedBox(height: 16),
            Text(
              l10n.arena_quiz_answered_waiting,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: BrainjaminColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (revealing) ...[
            const SizedBox(height: 12),
            Text(
              l10n.arena_quiz_reveal_next_in(
                _revealSecondsCeil(c.revealCountdownMs),
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: BrainjaminColors.brandOrange,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _OptionButton(
              label: i < options.length ? options[i] : '',
              index: i,
              selected: selected == i,
              revealing: revealing,
              correctIndex: correct,
              userSelected: selected,
              onTap: () => c.selectOption(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _submittingOverlay(ThemeData theme, AppLocalizations l10n) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.arena_quiz_submitting,
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
    AppLocalizations l10n,
    ArenaQuizController c,
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
                l10n.arena_quiz_submit_error,
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
                child: Text(l10n.arena_quiz_retry),
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

    var bg = BrainjaminColors.brandOrange.withValues(alpha: 0.08);
    var border = BrainjaminColors.brandOrange.withValues(alpha: 0.35);
    var opacity = 1.0;

    if (revealing && correctIndex != null) {
      final isCorrect = index == correctIndex;
      final isWrongPick =
          userSelected != null && userSelected == index && userSelected != correctIndex;

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
              border: Border.all(
                color: border,
                width: selected && !revealing ? 2 : 1,
              ),
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
