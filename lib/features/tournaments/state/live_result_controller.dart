import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/live_result.dart';
import '../data/live_tournament.dart';
import '../services/live_tournament_service.dart';

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
