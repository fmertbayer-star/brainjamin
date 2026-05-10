import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/services/server_time_service.dart';
import '../data/live_question_data.dart';
import '../data/live_tournament.dart';
import '../services/live_tournament_service.dart';

enum LiveQuizPhase {
  loading,
  awaitingQuestion,
  answering,
  revealing,
  submitting,
  submitted,
  error,
}

/// Passive Live quiz: follows server `live_tournaments` + `live_questions` snapshots only.
class LiveQuizController extends ChangeNotifier {
  LiveQuizController({
    required this.ltId,
    LiveTournamentService? service,
    this.onSubmittedSuccess,
    this.onTournamentAborted,
  }) : _service = service ?? LiveTournamentService() {
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (_) => _onTick(),
    );
    _liveSub = _service.watchOne(ltId).listen(_onLiveSnapshot);
  }

  static const int _answerWindowMs = 15000;
  static const int _revealDisplayMs = 3000;
  static const int _tickMs = 100;

  final String ltId;
  final LiveTournamentService _service;
  final void Function()? onSubmittedSuccess;
  final void Function(String message)? onTournamentAborted;

  StreamSubscription<LiveTournament?>? _liveSub;
  StreamSubscription<LiveQuestionData?>? _questionSub;

  Timer? _tickTimer;
  bool _disposed = false;

  int? _listeningQ;

  /// Ensures exactly one automatic submit pipeline when server reaches `ended`.
  bool _submitScheduled = false;

  LiveTournament? _liveDoc;
  LiveTournament? get liveDoc => _liveDoc;

  LiveQuestionData? _currentQuestion;
  LiveQuestionData? get currentQuestion => _currentQuestion;

  /// User selections per question index (only entries user tapped).
  final Map<int, int> _localSelections = {};
  final Map<int, int> _answerTapWallClockMs = {};

  /// Read-only view for tests / debugging.
  Map<int, int> get localSelectionsSnapshot => Map.unmodifiable(_localSelections);

  LiveQuizPhase _phase = LiveQuizPhase.loading;
  LiveQuizPhase get phase => _phase;

  int _answerCountdownMs = 0;
  int get answerCountdownMs => _answerCountdownMs;

  int _revealCountdownMs = 0;
  int get revealCountdownMs => _revealCountdownMs;

  /// Local clock anchor for reveal UI only (BRAINJAMIN — visual drift acceptable).
  DateTime? _revealStartLocal;

  String? _submitError;
  String? get submitError => _submitError;

  void _onTick() {
    if (_disposed) {
      return;
    }
    var changed = false;
    if (_phase == LiveQuizPhase.answering && _currentQuestion != null) {
      final v = _computeAnswerRemainingMs(_currentQuestion!);
      if (v != _answerCountdownMs) {
        _answerCountdownMs = v;
        changed = true;
      }
    }
    if (_phase == LiveQuizPhase.revealing && _revealStartLocal != null) {
      final v = _computeRevealRemainingMs();
      if (v != _revealCountdownMs) {
        _revealCountdownMs = v;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Gameplay countdown: server-adjusted instant vs question `started_at`.
  int _computeAnswerRemainingMs(LiveQuestionData q) {
    final startedMs = q.startedAt.millisecondsSinceEpoch;
    final nowMs = ServerTimeService.now().millisecondsSinceEpoch;
    return max(0, startedMs + _answerWindowMs - nowMs);
  }

  /// Reveal strip countdown: local wall clock only (not scored).
  int _computeRevealRemainingMs() {
    final start = _revealStartLocal!;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    return max(0, _revealDisplayMs - elapsed);
  }

  void _onLiveSnapshot(LiveTournament? live) {
    if (_disposed) {
      return;
    }
    _liveDoc = live;

    if (live == null) {
      if (!_terminalPhaseLocked()) {
        _phase = LiveQuizPhase.loading;
        notifyListeners();
      }
      return;
    }

    final st = live.status;
    if (st == 'no_participants' ||
        st == 'no_pool_questions' ||
        st == 'generation_failed') {
      onTournamentAborted?.call(
        "Tournament couldn't run — try the next slot.",
      );
      return;
    }

    if (st == 'ended') {
      _scheduleSubmitOnce();
    }

    _syncQuestionListener(live);

    if (!_terminalPhaseLocked()) {
      _derivePhase();
    }
    notifyListeners();
  }

  bool _terminalPhaseLocked() {
    return _phase == LiveQuizPhase.submitting ||
        _phase == LiveQuizPhase.submitted ||
        _phase == LiveQuizPhase.error;
  }

  void _syncQuestionListener(LiveTournament live) {
    final cq = live.currentQuestion;
    if (cq == _listeningQ) {
      return;
    }
    _questionSub?.cancel();
    _questionSub = null;
    _listeningQ = cq;
    _currentQuestion = null;

    if (cq != null) {
      _questionSub = _service.watchActiveQuestion(ltId, cq).listen(
        _onQuestionSnapshot,
      );
    }
  }

  void _onQuestionSnapshot(LiveQuestionData? q) {
    if (_disposed) {
      return;
    }
    final cq = _liveDoc?.currentQuestion;
    if (cq == null || q == null || q.qIndex != cq) {
      return;
    }

    final prevCorrect = _currentQuestion?.correctIndex;
    _currentQuestion = q;

    if (q.correctIndex != null && prevCorrect == null) {
      _revealStartLocal = DateTime.now();
      _revealCountdownMs = _revealDisplayMs;
    }
    if (q.correctIndex == null) {
      _revealStartLocal = null;
      _answerCountdownMs = _computeAnswerRemainingMs(q);
    }

    if (!_terminalPhaseLocked()) {
      _derivePhase();
    }
    notifyListeners();
  }

  void _derivePhase() {
    final live = _liveDoc;
    if (live == null) {
      _phase = LiveQuizPhase.loading;
      return;
    }

    switch (live.status) {
      case 'scheduled':
        _phase = LiveQuizPhase.awaitingQuestion;
        return;
      case 'running':
        final cq = live.currentQuestion;
        if (cq == null) {
          _phase = LiveQuizPhase.awaitingQuestion;
          return;
        }
        if (_currentQuestion == null || _currentQuestion!.qIndex != cq) {
          _phase = LiveQuizPhase.loading;
          return;
        }
        _phase = _currentQuestion!.correctIndex == null ?
            LiveQuizPhase.answering :
            LiveQuizPhase.revealing;
        return;
      default:
        _phase = LiveQuizPhase.awaitingQuestion;
    }
  }

  void _scheduleSubmitOnce() {
    if (_submitScheduled || _disposed) {
      return;
    }
    _submitScheduled = true;
    _phase = LiveQuizPhase.submitting;
    _submitError = null;
    notifyListeners();
    unawaited(_runSubmitWithRetry());
  }

  Future<void> _runSubmitWithRetry() async {
    Future<void> once() async {
      final answers = _buildSubmitPayload();
      await _service.submitAnswers(ltId, answers);
    }

    try {
      await once();
    } on Object catch (_) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed) {
        return;
      }
      try {
        await once();
      } on LiveSubmitException catch (e) {
        if (_disposed) {
          return;
        }
        _phase = LiveQuizPhase.error;
        _submitError = _messageForSubmitFailure(e);
        notifyListeners();
        return;
      } on Object catch (_) {
        if (_disposed) {
          return;
        }
        _phase = LiveQuizPhase.error;
        _submitError = 'unknown';
        notifyListeners();
        return;
      }
    }

    if (_disposed) {
      return;
    }
    _phase = LiveQuizPhase.submitted;
    notifyListeners();
    onSubmittedSuccess?.call();
  }

  String _messageForSubmitFailure(LiveSubmitException e) {
    switch (e.reason) {
      case LiveSubmitReason.notParticipant:
        return 'not_participant';
      case LiveSubmitReason.notEnded:
        return 'not_ended';
      case LiveSubmitReason.unknown:
        return 'unknown';
    }
  }

  List<LiveAnswerInput> _buildSubmitPayload() {
    final out = <LiveAnswerInput>[];
    for (final e in _localSelections.entries) {
      final tapMs = _answerTapWallClockMs[e.key];
      if (tapMs == null) {
        continue;
      }
      out.add(
        LiveAnswerInput(
          qIndex: e.key,
          selectedIndex: e.value,
          submittedAtMs: tapMs,
        ),
      );
    }
    return out;
  }

  /// During [LiveQuizPhase.answering] only; updates pick + tap timestamp.
  void selectOption(int optionIndex) {
    if (_disposed || _phase != LiveQuizPhase.answering) {
      return;
    }
    final cq = _liveDoc?.currentQuestion;
    if (cq == null || _currentQuestion?.qIndex != cq) {
      return;
    }
    if (optionIndex < 0 || optionIndex > 3) {
      return;
    }
    _localSelections[cq] = optionIndex;
    _answerTapWallClockMs[cq] = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  Future<void> retrySubmit() async {
    if (_liveDoc?.status != 'ended' || _disposed) {
      return;
    }
    _phase = LiveQuizPhase.submitting;
    _submitError = null;
    notifyListeners();
    await _runSubmitWithRetry();
  }

  @override
  void dispose() {
    _disposed = true;
    _tickTimer?.cancel();
    _liveSub?.cancel();
    _questionSub?.cancel();
    super.dispose();
  }
}
