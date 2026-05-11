import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/services/server_time_service.dart';
import '../data/arena_models.dart';
import '../data/arena_service.dart';

enum ArenaQuizPhase {
  loading,
  awaitingStart,
  answering,
  revealing,
  submitting,
  submitted,
  error,
}

/// Passive Arena list quiz: follows `arenas` + `arena_questions` snapshots only.
class ArenaQuizController extends ChangeNotifier {
  ArenaQuizController({
    required this.arenaId,
    ArenaService? service,
    this.onSubmittedSuccess,
    this.onArenaAborted,
  }) : _service = service ?? ArenaService() {
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      (_) => _onTick(),
    );
    _arenaSub = _service.watchArena(arenaId).listen(_onArenaSnapshot);
  }

  static const int kQuestionCount = 10;
  static const int _answerWindowMs = 15000;
  static const int _revealDisplayMs = 3000;
  static const int _tickMs = 100;

  final String arenaId;
  final ArenaService _service;
  final void Function()? onSubmittedSuccess;
  final void Function(String message)? onArenaAborted;

  StreamSubscription<ArenaDoc?>? _arenaSub;
  StreamSubscription<ArenaQuestionView?>? _questionSub;

  Timer? _tickTimer;
  bool _disposed = false;

  int? _listeningQ;

  bool _submitScheduled = false;

  ArenaDoc? _arenaDoc;
  ArenaDoc? get arenaDoc => _arenaDoc;

  ArenaQuestionView? _currentQuestion;
  ArenaQuestionView? get currentQuestion => _currentQuestion;

  final Map<int, int> _localSelections = {};
  final Map<int, int> _answerTapWallClockMs = {};

  Map<int, int> get localSelectionsSnapshot => Map.unmodifiable(_localSelections);

  ArenaQuizPhase _phase = ArenaQuizPhase.loading;
  ArenaQuizPhase get phase => _phase;

  int _answerCountdownMs = 0;
  int get answerCountdownMs => _answerCountdownMs;

  int _revealCountdownMs = 0;
  int get revealCountdownMs => _revealCountdownMs;

  DateTime? _revealStartLocal;

  String? _submitError;
  String? get submitError => _submitError;

  void _onTick() {
    if (_disposed) {
      return;
    }
    var changed = false;
    if (_phase == ArenaQuizPhase.answering && _currentQuestion != null) {
      final v = _computeAnswerRemainingMs(_currentQuestion!);
      if (v != _answerCountdownMs) {
        _answerCountdownMs = v;
        changed = true;
      }
    }
    if (_phase == ArenaQuizPhase.revealing && _revealStartLocal != null) {
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

  int _computeAnswerRemainingMs(ArenaQuestionView q) {
    final started = q.startedAt;
    if (started == null) {
      return _answerWindowMs;
    }
    final startedMs = started.millisecondsSinceEpoch;
    final nowMs = ServerTimeService.now().millisecondsSinceEpoch;
    return max(0, startedMs + _answerWindowMs - nowMs);
  }

  int _computeRevealRemainingMs() {
    final start = _revealStartLocal!;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    return max(0, _revealDisplayMs - elapsed);
  }

  void _onArenaSnapshot(ArenaDoc? doc) {
    if (_disposed) {
      return;
    }
    _arenaDoc = doc;

    if (doc == null) {
      if (!_terminalPhaseLocked()) {
        _phase = ArenaQuizPhase.loading;
        notifyListeners();
      }
      return;
    }

    final st = doc.status;
    if (st == 'no_participants' || st == 'generation_failed') {
      onArenaAborted?.call(
        "This arena couldn't run — head back and try again.",
      );
      notifyListeners();
      return;
    }

    if (st == 'ended') {
      _scheduleSubmitOnce();
    }

    _syncQuestionListener(doc);

    if (!_terminalPhaseLocked()) {
      _derivePhase();
    }
    notifyListeners();
  }

  bool _terminalPhaseLocked() {
    return _phase == ArenaQuizPhase.submitting ||
        _phase == ArenaQuizPhase.submitted ||
        _phase == ArenaQuizPhase.error;
  }

  void _syncQuestionListener(ArenaDoc doc) {
    final cq = doc.currentQuestion;
    if (cq == _listeningQ) {
      return;
    }
    _questionSub?.cancel();
    _questionSub = null;
    _listeningQ = cq;
    _currentQuestion = null;

    if (cq != null) {
      _questionSub = _service.watchActiveArenaQuestion(arenaId, cq).listen(
        _onQuestionSnapshot,
      );
    }
  }

  void _onQuestionSnapshot(ArenaQuestionView? q) {
    if (_disposed) {
      return;
    }
    final cq = _arenaDoc?.currentQuestion;
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
    final doc = _arenaDoc;
    if (doc == null) {
      _phase = ArenaQuizPhase.loading;
      return;
    }

    switch (doc.status) {
      case 'scheduled':
      case 'preparing':
        _phase = ArenaQuizPhase.awaitingStart;
        return;
      case 'running':
        final cq = doc.currentQuestion;
        if (cq == null) {
          _phase = ArenaQuizPhase.awaitingStart;
          return;
        }
        if (_currentQuestion == null || _currentQuestion!.qIndex != cq) {
          _phase = ArenaQuizPhase.loading;
          return;
        }
        _phase = _currentQuestion!.correctIndex == null
            ? ArenaQuizPhase.answering
            : ArenaQuizPhase.revealing;
        return;
      default:
        _phase = ArenaQuizPhase.awaitingStart;
    }
  }

  void _scheduleSubmitOnce() {
    if (_submitScheduled || _disposed) {
      return;
    }
    _submitScheduled = true;
    _phase = ArenaQuizPhase.submitting;
    _submitError = null;
    notifyListeners();
    unawaited(_runSubmitWithRetry());
  }

  List<ArenaAnswerInput> _buildSubmitPayload() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <ArenaAnswerInput>[];
    for (var i = 0; i < kQuestionCount; i++) {
      final sel = _localSelections[i];
      final tapMs = _answerTapWallClockMs[i];
      if (sel != null && tapMs != null) {
        out.add(
          ArenaAnswerInput(
            qIndex: i,
            selectedIndex: sel,
            submittedAtMs: tapMs,
          ),
        );
      } else {
        out.add(
          ArenaAnswerInput(
            qIndex: i,
            selectedIndex: -1,
            submittedAtMs: now,
          ),
        );
      }
    }
    out.sort((a, b) => a.qIndex.compareTo(b.qIndex));
    return out;
  }

  Future<void> _runSubmitWithRetry() async {
    Future<void> once() async {
      final answers = _buildSubmitPayload();
      await _service.submitArenaAnswers(arenaId: arenaId, answers: answers);
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
      } on ArenaSubmitException catch (e) {
        if (_disposed) {
          return;
        }
        _phase = ArenaQuizPhase.error;
        _submitError = _messageForSubmitFailure(e);
        notifyListeners();
        return;
      } on Object catch (_) {
        if (_disposed) {
          return;
        }
        _phase = ArenaQuizPhase.error;
        _submitError = 'unknown';
        notifyListeners();
        return;
      }
    }

    if (_disposed) {
      return;
    }
    _phase = ArenaQuizPhase.submitted;
    notifyListeners();
    onSubmittedSuccess?.call();
  }

  String _messageForSubmitFailure(ArenaSubmitException e) {
    switch (e.reason) {
      case ArenaSubmitReason.notParticipant:
        return 'not_participant';
      case ArenaSubmitReason.notEnded:
        return 'not_ended';
      case ArenaSubmitReason.unknown:
        return 'unknown';
    }
  }

  void selectOption(int optionIndex) {
    if (_disposed || _phase != ArenaQuizPhase.answering) {
      return;
    }
    final cq = _arenaDoc?.currentQuestion;
    if (cq == null || _currentQuestion?.qIndex != cq) {
      return;
    }
    if (_localSelections.containsKey(cq)) {
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
    if (_arenaDoc?.status != 'ended' || _disposed) {
      return;
    }
    _phase = ArenaQuizPhase.submitting;
    _submitError = null;
    notifyListeners();
    await _runSubmitWithRetry();
  }

  @override
  void dispose() {
    _disposed = true;
    _tickTimer?.cancel();
    _arenaSub?.cancel();
    _questionSub?.cancel();
    super.dispose();
  }
}
