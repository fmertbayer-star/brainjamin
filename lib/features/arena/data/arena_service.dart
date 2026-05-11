import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_config.dart';
import '../../../core/services/auth_service.dart';
import 'arena_models.dart';

class ArenaServiceException implements Exception {
  ArenaServiceException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ArenaServiceException($code, $message)';
}

enum ArenaSubmitReason {
  notEnded,
  notParticipant,
  unknown,
}

final class ArenaSubmitException implements Exception {
  ArenaSubmitException(this.reason);

  final ArenaSubmitReason reason;

  @override
  String toString() => 'ArenaSubmitException($reason)';
}

final class ArenaService {
  ArenaService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Map<String, dynamic> _map(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> createArena({
    required String mode,
    String? name,
    required String sourceType,
    String? categoryId,
    String? customTopic,
    required int scheduledStartAt,
  }) async {
    try {
      final callable = _functions.httpsCallable('createArena');
      final result = await callable.call({
        'mode': mode,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'sourceType': sourceType,
        if (categoryId != null && categoryId.trim().isNotEmpty)
          'categoryId': categoryId.trim(),
        if (customTopic != null && customTopic.trim().isNotEmpty)
          'customTopic': customTopic.trim(),
        'scheduledStartAt': scheduledStartAt,
      });
      return _map(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw ArenaServiceException(
        e.code,
        e.message ?? e.code,
        details: e.details is Map
            ? Map<String, dynamic>.from(e.details as Map)
            : null,
      );
    }
  }

  Future<Map<String, dynamic>> joinArena({
    String? inviteCode,
    String? arenaId,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (inviteCode != null && inviteCode.trim().isNotEmpty) {
        payload['invite_code'] = inviteCode.trim();
      }
      if (arenaId != null && arenaId.trim().isNotEmpty) {
        payload['arena_id'] = arenaId.trim();
      }
      final callable = _functions.httpsCallable('joinArena');
      final result = await callable.call(payload);
      return _map(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw ArenaServiceException(
        e.code,
        e.message ?? e.code,
        details: e.details is Map
            ? Map<String, dynamic>.from(e.details as Map)
            : null,
      );
    }
  }

  Future<Map<String, dynamic>> checkCustomTopicViability(String topic) async {
    try {
      final callable = _functions.httpsCallable('checkCustomTopicViability');
      final result = await callable.call({'topic': topic.trim()});
      return _map(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw ArenaServiceException(
        e.code,
        e.message ?? e.code,
      );
    }
  }

  Future<Map<String, dynamic>> generateArenaQuestions(String arenaId) async {
    try {
      final callable = _functions.httpsCallable(
        'generateArenaQuestions',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 540),
        ),
      );
      final result =
          await callable.call({'arena_id': arenaId.trim()});
      return _map(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw ArenaServiceException(
        e.code,
        e.message ?? e.code,
        details: e.details is Map
            ? Map<String, dynamic>.from(e.details as Map)
            : null,
      );
    }
  }

  Future<List<ArenaQuestionView>> getArenaQuestions(String arenaId) async {
    final id = arenaId.trim();
    final col = _firestore
        .collection('arena_questions')
        .doc(id)
        .collection('q');
    final snap = await col.get();
    final out = <ArenaQuestionView>[];
    for (final doc in snap.docs) {
      final qi = int.tryParse(doc.id, radix: 10);
      if (qi == null) {
        continue;
      }
      out.add(
        ArenaQuestionView.fromFirestore(
          id,
          qi,
          Map<String, dynamic>.from(doc.data()),
        ),
      );
    }
    out.sort((a, b) => a.qIndex.compareTo(b.qIndex));
    if (out.length != 10) {
      throw ArenaServiceException(
        'failed-precondition',
        'arena_questions_incomplete',
      );
    }
    return out;
  }

  /// `arenas/{arenaId}` — authoritative quiz pacing + finalize rollup.
  Stream<ArenaDoc?> watchArena(String arenaId) => listenToArena(arenaId);

  /// `arena_questions/{arenaId}/q/{qIndex}` — question text + reveal state.
  Stream<ArenaQuestionView?> watchActiveArenaQuestion(
    String arenaId,
    int qIndex,
  ) {
    final id = arenaId.trim();
    if (id.isEmpty) {
      return Stream<ArenaQuestionView?>.value(null);
    }
    return _firestore
        .collection('arena_questions')
        .doc(id)
        .collection('q')
        .doc('$qIndex')
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      try {
        return ArenaQuestionView.fromFirestore(
          id,
          qIndex,
          Map<String, dynamic>.from(snap.data()!),
        );
      } on Object catch (_) {
        return null;
      }
    });
  }

  Stream<List<ArenaLeaderboardEntry>> watchArenaLeaderboard(String arenaId) =>
      listenToArenaLeaderboard(arenaId);

  /// Current user's row under `arena_results/{arenaId}/users/{uid}`.
  Stream<ArenaMyResult?> watchMyArenaResult(String arenaId) {
    final trimmed = arenaId.trim();
    final uid = _auth.currentUser?.uid;
    if (trimmed.isEmpty || uid == null || uid.isEmpty) {
      return Stream<ArenaMyResult?>.value(null);
    }
    return _firestore
        .collection('arena_results')
        .doc(trimmed)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      try {
        return ArenaMyResult.fromFirestore(snap);
      } on Object catch (_) {
        return null;
      }
    });
  }

  /// After `arenas/{arenaId}.status == ended`. Payload: exactly 10 rows, `q_index` 0..9.
  Future<ArenaSubmitResult> submitArenaAnswers({
    required String arenaId,
    required List<ArenaAnswerInput> answers,
  }) async {
    await BrainjaminAuthService.ensureSignedIn();
    if (!BrainjaminAuthService.isSignedIn) {
      throw ArenaSubmitException(ArenaSubmitReason.unknown);
    }

    final id = arenaId.trim();
    try {
      final callable = _functions.httpsCallable(
        'submitArenaAnswers',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'arena_id': id,
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
      final m = _map(result.data);
      final ccRaw = m['correct_count'];
      final tamRaw = m['total_answer_ms'];
      final correctCount = ccRaw is int
          ? ccRaw
          : ccRaw is num
              ? ccRaw.toInt()
              : 0;
      final totalAnswerMs = tamRaw is int
          ? tamRaw
          : tamRaw is num
              ? tamRaw.toInt()
              : 0;
      return ArenaSubmitResult(
        arenaId: id,
        correctCount: correctCount,
        totalAnswerMs: totalAnswerMs,
        scored: m['scored'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      final msg = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();

      if (msg.contains('already scored') || msg.contains('already_scored')) {
        return ArenaSubmitResult(
          arenaId: id,
          correctCount: 0,
          totalAnswerMs: 0,
          scored: true,
        );
      }

      if (msg.contains('arena_not_ended')) {
        throw ArenaSubmitException(ArenaSubmitReason.notEnded);
      }
      if (msg.contains('not_a_participant')) {
        throw ArenaSubmitException(ArenaSubmitReason.notParticipant);
      }

      throw ArenaSubmitException(ArenaSubmitReason.unknown);
    }
  }

  Stream<ArenaDoc?> listenToArena(String arenaId) {
    return _firestore
        .collection('arenas')
        .doc(arenaId.trim())
        .snapshots()
        .map((s) {
      if (!s.exists || s.data() == null) {
        return null;
      }
      return ArenaDoc.fromFirestore(s.id, s.data()!);
    });
  }

  Stream<List<ArenaLeaderboardEntry>> listenToArenaLeaderboard(String arenaId) {
    return _firestore
        .collection('arena_leaderboards')
        .doc(arenaId.trim())
        .snapshots()
        .map((s) {
      if (!s.exists || s.data() == null) {
        return <ArenaLeaderboardEntry>[];
      }
      final raw = s.data()!['top_100'];
      if (raw is! List) {
        return <ArenaLeaderboardEntry>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (e) => ArenaLeaderboardEntry.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    });
  }

  Stream<List<ArenaParticipant>> listenToParticipants(String arenaId) {
    return _firestore
        .collection('arena_participants')
        .doc(arenaId.trim())
        .collection('users')
        .orderBy('joined_at')
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => ArenaParticipant.fromFirestore(d.id, d.data()))
          .toList();
    });
  }

  /// Current user's participant row for an arena (scores, rank, XP after finalize).
  Stream<ArenaParticipant?> listenToMyParticipant(String arenaId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<ArenaParticipant?>.value(null);
    }
    final id = arenaId.trim();
    return _firestore
        .collection('arena_participants')
        .doc(id)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) {
      if (!s.exists || s.data() == null) {
        return null;
      }
      return ArenaParticipant.fromFirestore(uid, s.data()!);
    });
  }

  Future<ArenaParticipant?> getMyParticipantDoc(String arenaId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    final snap = await _firestore
        .collection('arena_participants')
        .doc(arenaId.trim())
        .collection('users')
        .doc(uid)
        .get();
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    final base = ArenaParticipant.fromFirestore(uid, snap.data()!);
    final pub = await _firestore.collection('users_public').doc(uid).get();
    final name = pub.data()?['displayName'];
    String? dn;
    if (name is String && name.trim().isNotEmpty) {
      dn = name.trim();
    }
    return ArenaParticipant(
      uid: base.uid,
      joinedAt: base.joinedAt,
      isCreator: base.isCreator,
      status: base.status,
      displayName: dn,
      correctCount: base.correctCount,
      totalRemainingMs: base.totalRemainingMs,
      score: base.score,
      rank: base.rank,
      xpAwarded: base.xpAwarded,
    );
  }
}
