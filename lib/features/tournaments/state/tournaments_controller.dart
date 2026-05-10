import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/server_time_service.dart';
import '../data/live_tournament.dart';
import '../data/tournament.dart';
import '../data/tournament_list_item.dart';
import '../services/live_tournament_service.dart';

/// Single Firestore listener on [tournaments] with client-side split, plus
/// Live upcoming rows merged into [mergedUpcomingList].
///
/// Uses one query (`status` in visible|ended, `orderBy starts_at desc`, `limit 30`)
/// instead of two separate queries — simpler and one index; visibility/ended rows are
/// partitioned in [_applySnapshot].
class TournamentsController extends ChangeNotifier {
  TournamentsController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _liveService = LiveTournamentService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final LiveTournamentService _liveService;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<List<LiveTournament>>? _liveSub;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _classicReady = false;
  bool _liveReady = false;

  List<Tournament> _activeTournaments = [];
  List<Tournament> get activeTournaments => _activeTournaments;

  List<Tournament> _endedTournaments = [];
  List<Tournament> get endedTournaments => _endedTournaments;

  List<LiveTournament> _liveTournaments = [];

  /// Classic visible (non-ended) + Live scheduled/running, sorted by [startsAt] ascending.
  List<TournamentListItem> get mergedUpcomingList {
    final items = <TournamentListItem>[
      ..._activeTournaments
          .where((t) => !t.isEnded)
          .map(TournamentListItemClassic.new),
      ..._liveTournaments.map(TournamentListItemLive.new),
    ];
    items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return items;
  }

  /// Next 07:00 or 23:00 UTC boundary strictly after server-adjusted UTC "now".
  DateTime get nextSlotStartUtc => _computeNextClassicSlotUtc();

  void _tryFinishLoading() {
    if (_classicReady && _liveReady) {
      _isLoading = false;
    }
    notifyListeners();
  }

  void start() {
    stop();
    _isLoading = true;
    _error = null;
    _classicReady = false;
    _liveReady = false;
    notifyListeners();

    _sub = _firestore
        .collection('tournaments')
        .where('status', whereIn: ['visible', 'ended'])
        .orderBy('starts_at', descending: true)
        .limit(30)
        .snapshots()
        .listen(
      (snap) {
        try {
          final parsed = snap.docs.map(Tournament.fromFirestore).toList();
          _applySnapshot(parsed);
          _error = null;
        } catch (e, st) {
          _error = e.toString();
          if (kDebugMode) {
            debugPrint('TournamentsController parse error: $e\n$st');
          }
        }
        _classicReady = true;
        _tryFinishLoading();
      },
      onError: (Object e) {
        _error = e.toString();
        _classicReady = true;
        _tryFinishLoading();
      },
    );

    _liveSub = _liveService.watchUpcomingLive().listen(
      (rows) {
        _liveTournaments = rows;
        _liveReady = true;
        _tryFinishLoading();
      },
      onError: (Object e) {
        _liveTournaments = [];
        _liveReady = true;
        if (kDebugMode) {
          debugPrint('TournamentsController live stream error: $e');
        }
        _tryFinishLoading();
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _liveSub?.cancel();
    _liveSub = null;
  }

  void _applySnapshot(List<Tournament> all) {
    final now = ServerTimeService.now();
    final cutoff = now.subtract(const Duration(days: 14));

    final visible = all.where((t) => t.status == 'visible').toList()
      ..sort((a, b) {
        final aActive = a.isActive;
        final bActive = b.isActive;
        if (aActive != bActive) {
          return aActive ? -1 : 1;
        }
        return a.startsAt.compareTo(b.startsAt);
      });

    final ended = all
        .where(
          (t) =>
              t.status == 'ended' &&
              t.endsAt.isAfter(cutoff),
        )
        .toList()
      ..sort((a, b) => b.endsAt.compareTo(a.endsAt));

    _activeTournaments = visible;
    _endedTournaments = ended;
  }

  DateTime _computeNextClassicSlotUtc() {
    final offsetMs = ServerTimeService.offsetMs;
    final utcNow =
        DateTime.now().toUtc().add(Duration(milliseconds: offsetMs));
    final slots = <DateTime>[];
    for (var d = -1; d <= 3; d++) {
      final day = utcNow.add(Duration(days: d));
      slots.add(DateTime.utc(day.year, day.month, day.day, 7));
      slots.add(DateTime.utc(day.year, day.month, day.day, 23));
    }
    slots.sort();
    return slots.firstWhere((s) => s.isAfter(utcNow));
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
