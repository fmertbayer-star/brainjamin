import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/live_question_data.dart';
import '../data/live_result.dart';
import '../data/live_tournament.dart';
import '../services/live_tournament_service.dart';

/// Matches [TournamentCard] / tournament list category labels (snake_case → Title Case).
String _liveCategoryDisplayTitle(String categoryId) {
  if (categoryId.isEmpty) {
    return '?';
  }
  return categoryId
      .split('_')
      .map(
        (w) =>
            w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');
}

enum LiveResultPhase {
  loading,
  waitingFinalize,
  ready,
  error,
  timeout,
}

/// Listens to Live doc + user's `live_results` row; waits up to 90s for finalize.
class LiveResultController extends ChangeNotifier {
  LiveResultController({
    required this.ltId,
    LiveTournamentService? service,
  }) : _service = service ?? LiveTournamentService() {
    _liveSub = _service.watchOne(ltId).listen(_onLiveSnapshot);
    _resultSub = _service.watchMyResult(ltId).listen(_onMyResultSnapshot);
  }

  /// UI progress + countdown for the finalize wait window.
  static const int finalizeWaitTotalMs = 90000;

  final String ltId;
  final LiveTournamentService _service;

  StreamSubscription<LiveTournament?>? _liveSub;
  StreamSubscription<LiveResult?>? _resultSub;
  Timer? _finalizeWaitTimer;

  bool _disposed = false;

  LiveTournament? _liveDoc;
  LiveTournament? get liveDoc => _liveDoc;

  LiveResult? _myResult;
  LiveResult? get myResult => _myResult;

  List<LiveQuestionData> _liveQuestions = const [];
  bool _liveQuestionsLoading = false;
  bool _liveQuestionsFetchStarted = false;

  /// True while [fetchAllQuestions] is in flight for this result view.
  bool get liveQuestionsLoading => _liveQuestionsLoading;

  Map<String, ({int correct, int total})> _categoryStats = {};
  Map<String, ({int correct, int total})> get categoryStats => _categoryStats;

  /// Per-category rows sorted by total descending, then display name A–Z.
  List<({String categoryId, int correct, int total})> get categoryAccuracyRows {
    final entries = _categoryStats.entries
        .map(
          (e) => (
            categoryId: e.key,
            correct: e.value.correct,
            total: e.value.total,
          ),
        )
        .toList();
    entries.sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) {
        return byTotal;
      }
      return _liveCategoryDisplayTitle(a.categoryId)
          .compareTo(_liveCategoryDisplayTitle(b.categoryId));
    });
    return entries;
  }

  /// `total_answer_ms / 20 / 1000`, for scorecard copy.
  double get avgSecondsPerQuestion {
    final ms = _myResult?.totalAnswerMs ?? 0;
    return ms / 20 / 1000;
  }

  LiveResultPhase _phase = LiveResultPhase.loading;
  LiveResultPhase get phase => _phase;

  /// Milliseconds remaining while waiting for finalize (90s window).
  int waitTimeoutMs = finalizeWaitTotalMs;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _onLiveSnapshot(LiveTournament? live) {
    if (_disposed) {
      return;
    }
    _liveDoc = live;
    _reconcilePhaseFromLive();
    notifyListeners();
  }

  void _onMyResultSnapshot(LiveResult? result) {
    if (_disposed) {
      return;
    }
    _myResult = result;
    _recomputeCategoryStats();
    notifyListeners();
  }

  void _reconcilePhaseFromLive() {
    final live = _liveDoc;
    if (live == null) {
      if (_phase != LiveResultPhase.error) {
        _phase = LiveResultPhase.loading;
      }
      return;
    }

    if (live.finalizedAt != null) {
      _cancelFinalizeTimer();
      _phase = LiveResultPhase.ready;
      _errorMessage = null;
      _ensureLiveQuestionsFetched();
      return;
    }

    final st = live.status;
    if (st == 'no_participants') {
      _cancelFinalizeTimer();
      _phase = LiveResultPhase.error;
      _errorMessage = 'This tournament had no players.';
      return;
    }
    if (st == 'no_pool_questions' || st == 'generation_failed') {
      _cancelFinalizeTimer();
      _phase = LiveResultPhase.error;
      _errorMessage =
          "This one didn't quite get off the ground. Try the next slot.";
      return;
    }

    if (st == 'ended') {
      if (_phase == LiveResultPhase.timeout) {
        return;
      }
      if (_phase != LiveResultPhase.error) {
        _phase = LiveResultPhase.waitingFinalize;
        _tryStartFinalizeTimer();
      }
      return;
    }

    _cancelFinalizeTimer();
    if (_phase != LiveResultPhase.error && _phase != LiveResultPhase.timeout) {
      _phase = LiveResultPhase.loading;
    }
  }

  void _tryStartFinalizeTimer() {
    if (_finalizeWaitTimer != null) {
      return;
    }
    waitTimeoutMs = finalizeWaitTotalMs;
    _finalizeWaitTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onFinalizeTick,
    );
  }

  void _onFinalizeTick(Timer timer) {
    if (_disposed) {
      return;
    }
    if (_liveDoc?.finalizedAt != null) {
      _cancelFinalizeTimer();
      _phase = LiveResultPhase.ready;
      _ensureLiveQuestionsFetched();
      notifyListeners();
      return;
    }

    waitTimeoutMs -= 1000;
    if (waitTimeoutMs <= 0) {
      _cancelFinalizeTimer();
      if (_phase == LiveResultPhase.waitingFinalize) {
        _phase = LiveResultPhase.timeout;
      }
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  void _cancelFinalizeTimer() {
    _finalizeWaitTimer?.cancel();
    _finalizeWaitTimer = null;
  }

  void _ensureLiveQuestionsFetched() {
    if (_disposed || _liveQuestionsFetchStarted) {
      return;
    }
    _liveQuestionsFetchStarted = true;
    _liveQuestionsLoading = true;
    unawaited(_loadLiveQuestions());
  }

  Future<void> _loadLiveQuestions() async {
    try {
      final list = await _service.fetchAllQuestions(ltId);
      if (_disposed) {
        return;
      }
      _liveQuestions = list;
    } on Object catch (_) {
      if (!_disposed) {
        _liveQuestions = const [];
      }
    } finally {
      if (!_disposed) {
        _liveQuestionsLoading = false;
        _recomputeCategoryStats();
        notifyListeners();
      }
    }
  }

  void _recomputeCategoryStats() {
    if (_liveQuestions.isEmpty) {
      _categoryStats = {};
      return;
    }
    final answers = _myResult?.rawAnswers ?? const <LiveRawAnswer>[];
    final selectedByQIndex = <int, int?>{
      for (final a in answers) a.qIndex: a.selectedIndex,
    };
    final map = <String, ({int correct, int total})>{};
    for (final q in _liveQuestions) {
      final ci = q.correctIndex;
      if (ci == null) {
        continue;
      }
      final catKey = q.category.isEmpty ? '?' : q.category;
      final prev = map[catKey] ?? (correct: 0, total: 0);
      final sel = selectedByQIndex[q.qIndex];
      final ok = sel != null && sel == ci;
      map[catKey] = (
        correct: prev.correct + (ok ? 1 : 0),
        total: prev.total + 1,
      );
    }
    _categoryStats = map;
  }

  /// After [LiveResultPhase.timeout] — restarts the 90s wait while streams stay open.
  void retry() {
    if (_disposed) {
      return;
    }
    _cancelFinalizeTimer();
    waitTimeoutMs = finalizeWaitTotalMs;
    _phase = LiveResultPhase.waitingFinalize;
    _finalizeWaitTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onFinalizeTick,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelFinalizeTimer();
    _liveSub?.cancel();
    _resultSub?.cancel();
    super.dispose();
  }
}
