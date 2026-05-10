import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../push/widgets/push_primer_dialog.dart';
import '../data/daily_question_service.dart';
import '../state/daily_question_controller.dart';
import 'daily_overflow_menu.dart';

class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({
    super.key,
    this.controller,
  });

  final DailyQuestionController? controller;

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  late final DailyQuestionController _controller;
  bool _ownsController = true;
  bool _coachChecked = false;
  bool _showCoachOverlay = false;
  bool _savingCoachSeen = false;
  static const _anonCoachKey = 'tutorial_seen_daily';

  @override
  void initState() {
    super.initState();
    final sharedController = widget.controller;
    if (sharedController != null) {
      _controller = sharedController;
      _ownsController = false;
    } else {
      _controller = DailyQuestionController(service: DailyQuestionService());
      _ownsController = true;
    }
    _controller.addListener(_onControllerUpdated);
    _controller.onSubmitSuccess = () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        PushPrimerDialog.showIfNeeded(context);
      });
    };
    if (_ownsController) {
      _controller.init();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _controller.onSubmitSuccess = null;
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdated() {
    if (!_coachChecked &&
        (_controller.status == DailyQuestionStatus.ready ||
            _controller.status == DailyQuestionStatus.answered)) {
      _coachChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCoachIfNeeded();
      });
    }
  }

  Future<void> _showCoachIfNeeded() async {
    final shouldShow = await _shouldShowCoachMark();
    if (!mounted || !shouldShow) {
      return;
    }
    setState(() => _showCoachOverlay = true);
  }

  Future<bool> _shouldShowCoachMark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_anonCoachKey) ?? false);
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final tutorialSeen = data?['tutorialSeen'];
      if (tutorialSeen is Map<String, dynamic>) {
        return tutorialSeen['daily'] != true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _markCoachSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_anonCoachKey, true);
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'tutorialSeen': {'daily': true},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  List<Widget> _dailyAppBarActions() {
    final question = _controller.question;
    final showMenu =
        (_controller.status == DailyQuestionStatus.ready ||
            _controller.status == DailyQuestionStatus.answered) &&
        question != null;
    if (!showMenu) {
      return const [];
    }
    return [DailyOverflowMenu(questionId: question.qId)];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.daily_card_headline),
            actions: _dailyAppBarActions(),
          ),
          body: Stack(
            children: [
              switch (_controller.status) {
                DailyQuestionStatus.idle || DailyQuestionStatus.loading =>
                  _buildLoading(l10n),
                DailyQuestionStatus.error =>
                  _buildError(l10n),
                DailyQuestionStatus.ready =>
                  _buildReady(l10n),
                DailyQuestionStatus.answered =>
                  _buildAnswered(l10n),
              },
              if (_showCoachOverlay) _buildCoachOverlay(l10n),
            ],
          ),
        );
      },
    );
  }

  Future<void> _dismissCoachOverlay() async {
    if (_savingCoachSeen) {
      return;
    }
    setState(() => _savingCoachSeen = true);
    await _markCoachSeen();
    if (!mounted) {
      return;
    }
    setState(() {
      _showCoachOverlay = false;
      _savingCoachSeen = false;
    });
  }

  Widget _buildCoachOverlay(AppLocalizations l10n) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: BrainjaminColors.brandOrange,
                      child: Icon(Icons.psychology, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.daily_coach_title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.daily_coach_body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingCoachSeen ? null : _dismissCoachOverlay,
                      child: Text(l10n.daily_coach_cta),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
          Text(l10n.daily_screen_loading),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    final message = _controller.errorMessage == 'no_questions_available' ?
      l10n.daily_screen_error_no_questions :
      l10n.daily_screen_error_generic;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _controller.init,
              child: Text(l10n.daily_screen_retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReady(AppLocalizations l10n) {
    final question = _controller.question!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(question.category)),
        ),
        const SizedBox(height: 12),
        Text(
          question.questionText,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < question.options.length; i++) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _controller.isSubmitting ? null : () => _controller.submit(i),
              child: Text(question.options[i]),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildAnswered(AppLocalizations l10n) {
    final question = _controller.question!;
    final answerResult = _controller.answerResult;
    final correctIndex = question.correctIndex;
    final selectedIndex = question.selectedIndex;
    final isCorrect = question.isCorrect;
    final xpAwarded = question.xpAwarded;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ListView(
        key: const ValueKey<String>('answered'),
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(question.category)),
          ),
          const SizedBox(height: 12),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++) ...[
            _AnsweredOptionTile(
              text: question.options[i],
              isCorrectOption: correctIndex == i,
              isWrongSelection: selectedIndex == i && correctIndex != i,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isCorrect ?? false) ?
                BrainjaminColors.success.withValues(alpha: 0.12) :
                BrainjaminColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              (isCorrect ?? false) ?
                l10n.daily_screen_xp_correct(xpAwarded ?? 50) :
                l10n.daily_screen_xp_wrong(xpAwarded ?? 10),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (answerResult != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.daily_screen_streak_result(answerResult.streak),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ReactionMascot(
            isCorrect: isCorrect ?? false,
          ),
        ],
      ),
    );
  }
}

class _ReactionMascot extends StatelessWidget {
  const _ReactionMascot({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircleAvatar(
        radius: 34,
        backgroundColor: BrainjaminColors.brandOrange,
        child: Icon(
          isCorrect ?
            Icons.sentiment_satisfied_alt :
            Icons.sentiment_very_dissatisfied,
          color: Colors.white,
          size: 34,
        ),
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
    if (isCorrectOption) {
      border = BrainjaminColors.success;
      background = BrainjaminColors.success.withValues(alpha: 0.10);
    } else if (isWrongSelection) {
      border = BrainjaminColors.error;
      background = BrainjaminColors.error.withValues(alpha: 0.10);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        color: background,
      ),
      child: Text(text),
    );
  }
}
