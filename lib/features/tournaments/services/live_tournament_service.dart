import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_config.dart';
import '../../../core/services/auth_service.dart';
import '../data/live_question_data.dart';
import '../data/live_result.dart';
import '../data/live_tournament.dart';

enum LiveJoinReason {
  lateJoinClosed,
  tournamentEnded,
  unknown,
}

final class LiveJoinException implements Exception {
  LiveJoinException(this.reason);

  final LiveJoinReason reason;

  @override
  String toString() => 'LiveJoinException($reason)';
}

enum LiveSubmitReason {
  notEnded,
  notParticipant,
  unknown,
}

final class LiveSubmitException implements Exception {
  LiveSubmitException(this.reason);

  final LiveSubmitReason reason;

  @override
  String toString() => 'LiveSubmitException($reason)';
}

/// Single answer row for [submitLiveAnswers] callable (maps to snake_case payload).
final class LiveAnswerInput {
  const LiveAnswerInput({
    required this.qIndex,
    required this.selectedIndex,
    required this.submittedAtMs,
  });

  final int qIndex;
  final int? selectedIndex;
  final int submittedAtMs;
}

/// Firestore + callable gateway for Live tournaments (lobby + quiz).
final class LiveTournamentService {
  LiveTournamentService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const _collection = 'live_tournaments';

  Stream<List<LiveTournament>> watchUpcomingLive() {
    return _firestore
        .collection(_collection)
        .where('status', whereIn: ['scheduled', 'running'])
        .orderBy('starts_at')
        .limit(20)
        .snapshots()
        .map((snap) {
      final out = <LiveTournament>[];
      for (final doc in snap.docs) {
        try {
          out.add(LiveTournament.fromFirestore(doc));
        } on Object catch (_) {
          // Skip malformed docs; engine normally writes consistent shapes.
        }
      }
      return out;
    });
  }

  /// Current user's row under `live_results/{ltId}/users/{uid}`.
  Stream<LiveResult?> watchMyResult(String ltId) {
    final trimmed = ltId.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (trimmed.isEmpty || uid == null || uid.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('live_results')
        .doc(trimmed)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists) {
        return null;
      }
      try {
        return LiveResult.fromFirestore(snap);
      } on Object catch (_) {
        return null;
      }
    });
  }

  Stream<LiveTournament?> watchOne(String ltId) {
    final trimmed = ltId.trim();
    if (trimmed.isEmpty) {
      return Stream.value(null);
    }
    return _firestore.collection(_collection).doc(trimmed).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      try {
        return LiveTournament.fromFirestore(doc);
      } on Object catch (_) {
        return null;
      }
    });
  }

  /// All rows under `live_questions/{ltId}/q/*` (one-shot; sorted by [LiveQuestionData.qIndex]).
  Future<List<LiveQuestionData>> fetchAllQuestions(String ltId) async {
    final trimmed = ltId.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final snap = await _firestore
        .collection('live_questions')
        .doc(trimmed)
        .collection('q')
        .get();
    final out = <LiveQuestionData>[];
    for (final doc in snap.docs) {
      try {
        out.add(LiveQuestionData.fromFirestore(doc));
      } on Object catch (_) {
        // Skip malformed docs.
      }
    }
    out.sort((a, b) => a.qIndex.compareTo(b.qIndex));
    return out;
  }

  /// `live_questions/{ltId}/q/{qIndex}` — matches Cloud Functions `runLiveTournament`.
  Stream<LiveQuestionData?> watchActiveQuestion(String ltId, int qIndex) {
    final trimmed = ltId.trim();
    if (trimmed.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('live_questions')
        .doc(trimmed)
        .collection('q')
        .doc('$qIndex')
        .snapshots()
        .map((snap) {
      if (!snap.exists) {
        return null;
      }
      try {
        return LiveQuestionData.fromFirestore(snap);
      } on Object catch (_) {
        return null;
      }
    });
  }

  Future<void> join(String ltId) async {
    await BrainjaminAuthService.ensureSignedIn();
    if (!BrainjaminAuthService.isSignedIn) {
      throw LiveJoinException(LiveJoinReason.unknown);
    }

    try {
      final callable = _functions.httpsCallable('joinLiveTournament');
      await callable.call<Map<String, dynamic>>({'ltId': ltId.trim()});
    } on FirebaseFunctionsException catch (e) {
      final msg = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
      if (msg.contains('late_join_closed')) {
        throw LiveJoinException(LiveJoinReason.lateJoinClosed);
      }
      if (msg.contains('live_tournament_not_joinable')) {
        throw LiveJoinException(LiveJoinReason.tournamentEnded);
      }
      throw LiveJoinException(LiveJoinReason.unknown);
    }
  }

  /// Calls `submitLiveAnswers`. Treats backend “already scored” success as normal completion.
  Future<void> submitAnswers(String ltId, List<LiveAnswerInput> answers) async {
    await BrainjaminAuthService.ensureSignedIn();
    if (!BrainjaminAuthService.isSignedIn) {
      throw LiveSubmitException(LiveSubmitReason.unknown);
    }

    try {
      final callable = _functions.httpsCallable('submitLiveAnswers');
      await callable.call<Map<String, dynamic>>({
        'ltId': ltId.trim(),
        'answers': answers
            .map(
              (a) => <String, dynamic>{
                'q_index': a.qIndex,
                'selected_index': a.selectedIndex,
                'submitted_at_ms': a.submittedAtMs,
              },
            )
            .toList(),
      });
    } on FirebaseFunctionsException catch (e) {
      final msg = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();

      if (msg.contains('already scored') || msg.contains('already_scored')) {
        return;
      }

      if (msg.contains('live_tournament_not_ended')) {
        throw LiveSubmitException(LiveSubmitReason.notEnded);
      }
      if (msg.contains('not_a_participant')) {
        throw LiveSubmitException(LiveSubmitReason.notParticipant);
      }

      throw LiveSubmitException(LiveSubmitReason.unknown);
    }
  }
}
