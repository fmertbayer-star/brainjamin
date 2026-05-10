import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/mascot_empty_state.dart';
import 'state/classic_quiz_controller.dart';

/// Classic tournament quiz — 20 questions, draft persistence, no timer (Sprint 4.4b-ii-1).
class ClassicQuizScreen extends StatefulWidget {
  const ClassicQuizScreen({super.key, required this.slotId});

  final String slotId;

  @override
  State<ClassicQuizScreen> createState() => _ClassicQuizScreenState();
}

class _ClassicQuizScreenState extends State<ClassicQuizScreen> {
  ClassicQuizController? _controller;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _controller = ClassicQuizController(slotId: widget.slotId, uid: uid);
    _controller!.addListener(_onCtrl);
    unawaited(_controller!.start());
  }

  void _onCtrl() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onCtrl);
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> _showQuitDialog(AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.classicQuizQuitTitle),
          content: Text(l10n.classicQuizQuitBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.classicQuizQuitStay),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.classicQuizQuitLeave),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _onWillPop() async {
    final l10n = AppLocalizations.of(context);
    final leave = await _showQuitDialog(l10n);
    if (leave && mounted) {
      context.go('/tournament/${widget.slotId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _onWillPop,
          ),
          title: Text(
            l10n.classicQuizAppBarTitle(c.currentIndex + 1, 20),
          ),
        ),
        body: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            return switch (c.status) {
              ClassicQuizStatus.idle ||
              ClassicQuizStatus.loading =>
                _buildLoading(l10n),
              ClassicQuizStatus.error => _buildError(context, l10n, c),
              ClassicQuizStatus.alreadySubmitted =>
                _buildAlreadySubmitted(context, l10n),
              ClassicQuizStatus.ready ||
              ClassicQuizStatus.submitting =>
                _buildQuizBody(context, l10n, theme, c),
              ClassicQuizStatus.submitted =>
                _buildSubmitted(context, l10n, c),
            };
          },
        ),
      ),
    );
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(l10n.classicQuizLoadingText),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    AppLocalizations l10n,
    ClassicQuizController c,
  ) {
    final msg = c.isWindowClosedError ?
        l10n.classicQuizErrorWindowClosed :
        (c.error != null && c.error!.isNotEmpty ?
            c.error! :
            l10n.classicQuizErrorGeneric);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => c.start(),
            child: Text(l10n.classicQuizErrorRetry),
          ),
          TextButton(
            onPressed: () => context.go('/tournament/${widget.slotId}'),
            child: Text(l10n.classicQuizErrorBack),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySubmitted(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MascotEmptyState(
            title: l10n.classicQuizAlreadySubmittedTitle,
            body: l10n.classicQuizAlreadySubmittedBody,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/tournament/${widget.slotId}'),
            child: Text(l10n.classicQuizSubmittedBackCta),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizBody(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ClassicQuizController c,
  ) {
    final questions = c.questions;
    final draft = c.draft;
    if (questions == null || draft == null) {
      return Center(child: Text(l10n.classicQuizErrorGeneric));
    }

    final idx = c.currentIndex.clamp(0, 19);
    final q = questions[idx];
    final submitting = c.isSubmitting;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (idx + 1) / 20,
                  backgroundColor:
                      BrainjaminColors.onSurfaceMuted.withValues(alpha: 0.2),
                  color: BrainjaminColors.brandOrange,
                  minHeight: 6,
                ),
              ),
            ),
            // V2 polish: sticky question selector — not in Sprint 4.4b-ii-1 scope.
            Expanded(
              child: KeyedSubtree(
                key: ValueKey<int>(idx),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          side: const BorderSide(
                            color: BrainjaminColors.brandOrange,
                          ),
                          label: Text(q.category),
                          labelStyle: const TextStyle(
                            color: BrainjaminColors.brandOrangeDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.question,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < q.options.length; i++) ...[
                        _OptionRow(
                          label: q.options[i],
                          selected: draft.answers[idx] == i,
                          onTap: submitting ?
                              null :
                              () => c.selectOption(i),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed:
                                idx > 0 && !submitting ? c.previous : null,
                            child: Text(l10n.classicQuizPreviousButton),
                          ),
                          Expanded(
                            child: Text(
                              l10n.classicQuizAnsweredCounter(
                                draft.answeredCount,
                                20,
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: BrainjaminColors.onSurfaceMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: idx < 19
                                  ? TextButton(
                                      onPressed: submitting ? null : c.next,
                                      child: Text(l10n.classicQuizNextButton),
                                    )
                                  : _SubmitSide(
                                      l10n: l10n,
                                      enabled:
                                          draft.isComplete && !submitting,
                                      onSubmit: () => unawaited(c.submit()),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (idx == 19 && !draft.isComplete)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.classicQuizSubmitDisabledHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: BrainjaminColors.onSurfaceMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                        Text(l10n.classicQuizLoadingText),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitted(
    BuildContext context,
    AppLocalizations l10n,
    ClassicQuizController c,
  ) {
    final count = c.submittedCorrectCount ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 72,
              color: BrainjaminColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.classicQuizSubmittedTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.classicQuizSubmittedBody(count),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  context.go('/tournament/${widget.slotId}/result'),
              child: Text(l10n.classicQuizSubmittedBackCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: BrainjaminColors.brandOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: onTap,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(Icons.radio_button_unchecked, color: BrainjaminColors.onSurfaceMuted),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}

class _SubmitSide extends StatelessWidget {
  const _SubmitSide({
    required this.l10n,
    required this.enabled,
    required this.onSubmit,
  });

  final AppLocalizations l10n;
  final bool enabled;
  final void Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onSubmit : null,
      style: FilledButton.styleFrom(
        backgroundColor: BrainjaminColors.brandOrange,
        foregroundColor: Colors.white,
      ),
      child: Text(l10n.classicQuizSubmitButton),
    );
  }
}
