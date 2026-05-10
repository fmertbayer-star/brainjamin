import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firebase_config.dart';
import '../constants/firestore_collections.dart';
import '../utils/safe_stream_cancel.dart';

/// Client-side gateway to Duel Cloud Functions and Firestore listeners.
///
/// Wraps the 5 callable functions (getDuelLobbyStats, createDuel, joinDuel,
/// getDuelQuestions, submitDuelAnswers) plus two Firestore stream helpers
/// (single-duel listener + my-duels merged listener), and a lightweight
/// fetch for duel_questions metadata used on the result screen.
class DuelService {
  DuelService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> getDuelLobbyStats() async {
    final callable = _functions.httpsCallable('getDuelLobbyStats');
    final result = await callable.call();
    return _toMap(result.data);
  }

  Future<Map<String, dynamic>> createDuel({
    String? category,
    required String type,
  }) async {
    final callable = _functions.httpsCallable('createDuel');
    final result = await callable.call({
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
      'type': type,
    });
    return _toMap(result.data);
  }

  Future<Map<String, dynamic>> joinDuel({
    String? duelId,
    String? inviteCode,
  }) async {
    final callable = _functions.httpsCallable('joinDuel');
    final result = await callable.call({
      if (duelId != null && duelId.trim().isNotEmpty) 'duelId': duelId.trim(),
      if (inviteCode != null && inviteCode.trim().isNotEmpty)
        'inviteCode': inviteCode.trim().toUpperCase(),
    });
    return _toMap(result.data);
  }

  Future<Map<String, dynamic>> getDuelQuestions(String duelId) async {
    final callable = _functions.httpsCallable('getDuelQuestions');
    final result = await callable.call({'duelId': duelId});
    return _toMap(result.data);
  }

  Future<Map<String, dynamic>> submitDuelAnswers({
    required String duelId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final callable = _functions.httpsCallable('submitDuelAnswers');
    final result = await callable.call({
      'duelId': duelId,
      'answers': answers,
    });
    return _toMap(result.data);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getMyDuels() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final p1 = await _firestore
        .collection(FirestoreCollections.duels)
        .where('player1_id', isEqualTo: uid)
        .get();
    final p2 = await _firestore
        .collection(FirestoreCollections.duels)
        .where('player2_id', isEqualTo: uid)
        .get();
    final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in p1.docs) {
      merged[d.id] = d;
    }
    for (final d in p2.docs) {
      merged[d.id] = d;
    }
    final list = merged.values.toList();
    list.sort((a, b) {
      final am = _toMs(a.data()['created_at']);
      final bm = _toMs(b.data()['created_at']);
      return bm.compareTo(am);
    });
    return list;
  }

  /// Lightweight metadata from `duel_questions/{duelId}/q/*` for result UI (category / difficulty).
  Future<List<DuelQuestionMetadataRow>> fetchDuelQuestionsMetadata(String duelId) async {
    final id = duelId.trim();
    if (id.isEmpty) return const [];
    final snap = await _firestore
        .collection(FirestoreCollections.duelQuestions)
        .doc(id)
        .collection('q')
        .get();
    final out = <DuelQuestionMetadataRow>[];
    for (final d in snap.docs) {
      final m = d.data();
      final catRaw = m['category'];
      final diffRaw = m['difficulty'];
      final cat = catRaw is String ? catRaw : catRaw?.toString();
      out.add(
        DuelQuestionMetadataRow(
          category: cat,
          difficulty: _asIntMeta(diffRaw),
        ),
      );
    }
    return out;
  }

  static int? _asIntMeta(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToDuel(String duelId) {
    return _firestore
        .collection(FirestoreCollections.duels)
        .doc(duelId)
        .snapshots();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> listenMyDuels() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    final c = StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>();
    List<QueryDocumentSnapshot<Map<String, dynamic>>> p1Docs = const [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> p2Docs = const [];

    void emit() {
      final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final d in p1Docs) {
        merged[d.id] = d;
      }
      for (final d in p2Docs) {
        merged[d.id] = d;
      }
      final list = merged.values.toList();
      list.sort((a, b) => _toMs(b.data()['created_at']).compareTo(_toMs(a.data()['created_at'])));
      c.add(list);
    }

    final s1 = _firestore
        .collection(FirestoreCollections.duels)
        .where('player1_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      p1Docs = snap.docs;
      emit();
    }, onError: c.addError);
    final s2 = _firestore
        .collection(FirestoreCollections.duels)
        .where('player2_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      p2Docs = snap.docs;
      emit();
    }, onError: c.addError);

    c.onCancel = () async {
      await safeCancelSubscription(s1);
      await safeCancelSubscription(s2);
    };
    return c.stream;
  }

  static int _toMs(dynamic v) {
    if (v is Timestamp) return v.toDate().millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  static Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}

/// One row of metadata from `duel_questions/{duelId}/q/{index}` (result screen summary only).
class DuelQuestionMetadataRow {
  const DuelQuestionMetadataRow({
    this.category,
    this.difficulty,
  });

  final String? category;
  final int? difficulty;
}
