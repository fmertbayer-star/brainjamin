import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_config.dart';
import 'arena_models.dart';

class ArenaServiceException implements Exception {
  ArenaServiceException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ArenaServiceException($code, $message)';
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
      final callable = _functions.httpsCallable('generateArenaQuestions');
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

  Future<Map<String, dynamic>> submitArenaAnswers({
    required String arenaId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitArenaAnswers');
      final result = await callable.call({
        'arena_id': arenaId.trim(),
        'answers': answers,
      });
      return _map(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw ArenaServiceException(
        e.code,
        e.message ?? e.code,
      );
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

  /// Public display names for lobby list (batch read).
  Future<Map<String, String?>> loadParticipantDisplayNames(
    List<String> uids,
  ) async {
    final out = <String, String?>{};
    for (final uid in uids.toSet()) {
      final pub = await _firestore.collection('users_public').doc(uid).get();
      final name = pub.data()?['displayName'];
      if (name is String && name.trim().isNotEmpty) {
        out[uid] = name.trim();
      } else {
        out[uid] = null;
      }
    }
    return out;
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
