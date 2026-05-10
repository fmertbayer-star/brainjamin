import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/classic_reveal.dart';
import '../data/tournament.dart';
import '../data/tournament_session.dart';
import '../services/tournament_callables.dart';

enum ClassicResultMode {
  loading,
  pending,
  finalized,
  redirectToQuiz,
  redirectToDetail,
  error,
}

class ClassicResultController extends ChangeNotifier {
  ClassicResultController({
    required this.slotId,
    required this.uid,
    FirebaseFirestore? firestore,
    TournamentCallables? callables,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _callables = callables ?? TournamentCallables();

  final String slotId;
  final String uid;
  final FirebaseFirestore _firestore;
  final TournamentCallables _callables;

  ClassicResultMode _mode = ClassicResultMode.loading;
  ClassicResultMode get mode => _mode;

  String? _error;
  String? get error => _error;

  Tournament? _tournament;
  Tournament? get tournament => _tournament;

  TournamentSession? _session;
  TournamentSession? get session => _session;

  ClassicReveal? _reveal;
  ClassicReveal? get reveal => _reveal;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tournamentSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;

  bool _hasTournamentLoaded = false;
  bool _hasSessionLoaded = false;
  bool _isFetchingReveal = false;
  bool _revealFetched = false;

  void start() {
    stop();
    _mode = ClassicResultMode.loading;
    _error = null;
    _tournament = null;
    _session = null;
    _reveal = null;
    _hasTournamentLoaded = false;
    _hasSessionLoaded = false;
    _isFetchingReveal = false;
    _revealFetched = false;
    notifyListeners();

    if (slotId.isEmpty || uid.isEmpty) {
      _mode = ClassicResultMode.redirectToDetail;
      notifyListeners();
      return;
    }

    _tournamentSub = _firestore.collection('tournaments').doc(slotId).snapshots().listen(
      (snap) {
        try {
          _tournament = snap.exists ? Tournament.fromFirestore(snap) : null;
          _hasTournamentLoaded = true;
          _evaluateMode();
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('ClassicResultController tournament parse: $e\n$st');
          }
          _mode = ClassicResultMode.error;
          _error = 'tournament_parse_error';
          notifyListeners();
        }
      },
      onError: (Object e) {
        _mode = ClassicResultMode.error;
        _error = e.toString();
        notifyListeners();
      },
    );

    final sessionId = '${slotId}_$uid';
    _sessionSub = _firestore
        .collection('tournament_sessions')
        .doc(sessionId)
        .snapshots()
        .listen(
      (snap) {
        try {
          _session = snap.exists ? TournamentSession.fromFirestore(snap) : null;
          _hasSessionLoaded = true;
          _evaluateMode();
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('ClassicResultController session parse: $e\n$st');
          }
          _mode = ClassicResultMode.error;
          _error = 'session_parse_error';
          notifyListeners();
        }
      },
      onError: (Object e) {
        _mode = ClassicResultMode.error;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void _evaluateMode() {
    if (!_hasTournamentLoaded || !_hasSessionLoaded) {
      _mode = ClassicResultMode.loading;
      notifyListeners();
      return;
    }

    final s = _session;
    if (s == null) {
      _mode = ClassicResultMode.redirectToDetail;
      notifyListeners();
      return;
    }

    if (s.isInProgress) {
      _mode = ClassicResultMode.redirectToQuiz;
      notifyListeners();
      return;
    }

    if (!s.isSubmitted) {
      _mode = ClassicResultMode.error;
      _error = 'session_status_invalid';
      notifyListeners();
      return;
    }

    final t = _tournament;
    if (t == null) {
      _mode = ClassicResultMode.error;
      _error = 'tournament_missing';
      notifyListeners();
      return;
    }

    if (t.status != 'ended') {
      _mode = ClassicResultMode.pending;
      notifyListeners();
      return;
    }

    if (_reveal != null) {
      _mode = ClassicResultMode.finalized;
      notifyListeners();
      return;
    }

    if (_isFetchingReveal || _revealFetched) {
      _mode = ClassicResultMode.loading;
      notifyListeners();
      return;
    }

    _isFetchingReveal = true;
    _mode = ClassicResultMode.loading;
    notifyListeners();
    _fetchReveal();
  }

  Future<void> _fetchReveal() async {
    try {
      final r = await _callables.getClassicTournamentReveal(slotId);
      _reveal = r;
      _revealFetched = true;
      _mode = ClassicResultMode.finalized;
      _error = null;
    } catch (e) {
      _mode = ClassicResultMode.error;
      _error = e.toString();
    } finally {
      _isFetchingReveal = false;
      notifyListeners();
    }
  }

  void stop() {
    _tournamentSub?.cancel();
    _tournamentSub = null;
    _sessionSub?.cancel();
    _sessionSub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
