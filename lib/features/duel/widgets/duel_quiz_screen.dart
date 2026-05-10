import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/duel_service.dart';

class DuelQuizScreen extends StatefulWidget {
  const DuelQuizScreen({super.key});

  @override
  State<DuelQuizScreen> createState() => _DuelQuizScreenState();
}

class _DuelQuestionView {
  const _DuelQuestionView({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<String> options;
  final int? correctIndex;
}

class _DraftAnswer {
  const _DraftAnswer({
    required this.questionIndex,
    required this.selectedOption,
    required this.timeMs,
  });

  final int questionIndex;
  final int selectedOption;
  final int timeMs;

  Map<String, dynamic> toPayload() {
    return {
      'questionIndex': questionIndex,
      'selectedOption': selectedOption,
      'timeMs': timeMs,
    };
  }
}

class _DuelQuizScreenState extends State<DuelQuizScreen>
    with SingleTickerProviderStateMixin {
  static const int _questionCount = 10;
  static const int _questionTimeMs = 15000;

  final DuelService _duelService = DuelService();
  late final AnimationController _timer;

  String? _duelId;
  bool _invalidParams = false;
  bool _loading = true;
  bool _submitting = false;
  bool _revealing = false;
  String? _loadError;
  List<_DuelQuestionView> _questions = const [];
  List<_DraftAnswer> _answers = const [];
  int _currentIndex = 0;
  int? _selectedOption;

  bool get _quizInProgress =>
      !_loading &&
      _loadError == null &&
      _questions.isNotEmpty &&
      !_submitting &&
      _currentIndex < _questions.length;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _questionTimeMs),
    )..addStatusListener(_onTimerStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_duelId != null || _invalidParams) return;
    final duelId = GoRouterState.of(context).uri.queryParameters['duelId'];
    if (duelId == null || duelId.isEmpty) {
      setState(() {
        _invalidParams = true;
        _loading = false;
      });
      return;
    }
    _duelId = duelId;
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (_duelId == null) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await _duelService.getDuelQuestions(_duelId!);
      final rawQuestions = result['questions'];
      if (rawQuestions is! List) {
        throw StateError('questions payload missing');
      }
      final parsed = <_DuelQuestionView>[];
      for (final raw in rawQuestions) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final question = m['question'];
        final options = m['options'];
        final correctIndex = m['correctIndex'];
        if (question is! String || options is! List) continue;
        final parsedOptions = options.whereType<String>().toList();
        if (parsedOptions.length != 4) continue;
        parsed.add(
          _DuelQuestionView(
            question: question,
            options: parsedOptions,
            correctIndex: correctIndex is int ? correctIndex : null,
          ),
        );
      }
      if (parsed.length != _questionCount) {
        throw StateError('Expected 10 questions, got ${parsed.length}');
      }
      if (!mounted) return;
      setState(() {
        _questions = parsed;
        _answers = [];
        _currentIndex = 0;
        _selectedOption = null;
        _revealing = false;
        _loading = false;
      });
      _startQuestionTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _startQuestionTimer() {
    _timer
      ..stop()
      ..reset()
      ..forward();
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_quizInProgress || _revealing) return;
    _recordAndReveal(-1);
  }

  void _recordAndReveal(int selectedOption) {
    if (!_quizInProgress || _revealing) return;
    _timer.stop();
    final elapsedMs = (_timer.value * _questionTimeMs).round().clamp(0, _questionTimeMs);
    final nextAnswers = List<_DraftAnswer>.from(_answers)
      ..add(
        _DraftAnswer(
          questionIndex: _currentIndex,
          selectedOption: selectedOption,
          timeMs: elapsedMs,
        ),
      );
    setState(() {
      _answers = nextAnswers;
      _selectedOption = selectedOption;
      _revealing = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _advanceOrSubmit();
    });
  }

  Future<void> _advanceOrSubmit() async {
    if (_currentIndex >= _questions.length - 1) {
      await _submitAnswers();
      return;
    }
    setState(() {
      _currentIndex += 1;
      _selectedOption = null;
      _revealing = false;
    });
    _startQuestionTimer();
  }

  Future<void> _submitAnswers() async {
    if (_duelId == null || _submitting) return;
    setState(() {
      _submitting = true;
    });
    try {
      await _duelService.submitDuelAnswers(
        duelId: _duelId!,
        answers: _answers.map((a) => a.toPayload()).toList(),
      );
      if (!mounted) return;
      final uri = Uri(path: '/duel/result', queryParameters: {'duelId': _duelId!});
      context.go(uri.toString());
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.duelQuizSubmitError}\n${error.toString()}'),
          action: SnackBarAction(
            label: l10n.duelQuizSubmitRetry,
            onPressed: _submitAnswers,
          ),
        ),
      );
      setState(() {
        _submitting = false;
      });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_invalidParams) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.duelQuizTitle)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.duelQuizError),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/duel'),
                child: Text(l10n.duelQuizErrorBack),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.duelQuizTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.duelQuizLoading),
            ],
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.duelQuizTitle)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${l10n.duelQuizError}\n$_loadError'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/duel'),
                child: Text(l10n.duelQuizErrorBack),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final interceptBack = _quizInProgress;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.duelQuizProgress(_currentIndex + 1, _questions.length)),
      ),
      body: PopScope(
        canPop: !interceptBack,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || !interceptBack) return;
          final shouldQuit = await _showQuitConfirmDialog();
          if (shouldQuit && context.mounted) {
            context.go('/duel');
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
                      Chip(label: Text(l10n.duelQuizTimer(seconds))),
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
                      style: _buildOptionStyle(i),
                      onPressed: (_revealing || _submitting) ? null : () => _recordAndReveal(i),
                      child: Text(question.options[i]),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_submitting) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(l10n.duelQuizSubmitting),
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

  ButtonStyle? _buildOptionStyle(int index) {
    if (!_revealing) return null;
    final correctIndex = _questions[_currentIndex].correctIndex;
    Color? bgColor;
    final isSelected = _selectedOption == index;
    if (correctIndex != null && correctIndex == index) {
      bgColor = Colors.green;
    } else if (correctIndex == null && isSelected && _selectedOption != -1) {
      bgColor = Colors.green;
    } else if (_selectedOption == -1) {
      bgColor = null;
    } else if (isSelected) {
      bgColor = Colors.red;
    } else {
      bgColor = null;
    }
    if (bgColor == null) return null;
    return ElevatedButton.styleFrom(backgroundColor: bgColor);
  }
}
