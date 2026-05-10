import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/tournament.dart';
import '../data/tournament_session.dart';

/// Live tournament row + session for [slotId], independent of [TournamentsController].
class TournamentDetailController extends ChangeNotifier {
  TournamentDetailController({
    required this.slotId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final String slotId;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tournamentSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  StreamSubscription<User?>? _authSub;

  bool _isLoadingTournament = true;
  bool get isLoadingTournament => _isLoadingTournament;

  bool _isLoadingSession = false;
  bool get isLoadingSession => _isLoadingSession;

  String? _error;
  String? get error => _error;

  Tournament? _tournament;
  Tournament? get tournament => _tournament;

  TournamentSession? _session;
  TournamentSession? get session => _session;

  String? get uid => _auth.currentUser?.uid;

  DateTime? get endsAt => _tournament?.endsAt;

  void start() {
    stop();
    _error = null;
    _tournament = null;
    _session = null;
    _isLoadingTournament = true;
    _isLoadingSession = false;
    notifyListeners();

    if (slotId.isEmpty) {
      _isLoadingTournament = false;
      notifyListeners();
      return;
    }

    final tournamentRef = _firestore.collection('tournaments').doc(slotId);
    _tournamentSub = tournamentRef.snapshots().listen(
      (snap) {
        try {
          if (!snap.exists) {
            _tournament = null;
          } else {
            _tournament = Tournament.fromFirestore(snap);
          }
          _error = null;
        } catch (e, st) {
          _tournament = null;
          _error = e.toString();
          if (kDebugMode) {
            debugPrint('TournamentDetailController tournament parse: $e\n$st');
          }
        }
        _isLoadingTournament = false;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoadingTournament = false;
        _tournament = null;
        notifyListeners();
      },
    );

    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
    _attachSessionListenerForCurrentUser();
  }

  void _onAuthChanged(User? _) {
    _attachSessionListenerForCurrentUser();
  }

  void _attachSessionListenerForCurrentUser() {
    _sessionSub?.cancel();
    _sessionSub = null;

    final u = _auth.currentUser?.uid;
    if (u == null) {
      _session = null;
      _isLoadingSession = false;
      notifyListeners();
      return;
    }

    _isLoadingSession = true;
    notifyListeners();

    final sessionId = '${slotId}_$u';
    final sessionRef = _firestore.collection('tournament_sessions').doc(sessionId);

    _sessionSub = sessionRef.snapshots().listen(
      (snap) {
        try {
          if (!snap.exists) {
            _session = null;
          } else {
            _session = TournamentSession.fromFirestore(snap);
          }
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('TournamentDetailController session parse: $e\n$st');
          }
          _session = null;
        }
        _isLoadingSession = false;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('TournamentDetailController session stream: $e\n$st');
        }
        _isLoadingSession = false;
        notifyListeners();
      },
    );
  }

  void stop() {
    _tournamentSub?.cancel();
    _tournamentSub = null;
    _sessionSub?.cancel();
    _sessionSub = null;
    _authSub?.cancel();
    _authSub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
