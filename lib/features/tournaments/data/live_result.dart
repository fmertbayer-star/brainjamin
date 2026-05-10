import 'package:cloud_firestore/cloud_firestore.dart';

/// User row under `live_results/{ltId}/users/{uid}`.
class LiveResult {
  const LiveResult({
    required this.uid,
    required this.correctCount,
    required this.totalAnswerMs,
    required this.rank,
    required this.xpAwarded,
    required this.xpGrantedAt,
    required this.scored,
    required this.submittedAt,
  });

  final String uid;
  final int correctCount;
  final int totalAnswerMs;
  final int? rank;
  final int? xpAwarded;
  final DateTime? xpGrantedAt;
  final bool scored;
  final DateTime submittedAt;

  factory LiveResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError.value(doc.id, 'doc', 'missing live result data');
    }

    final rankRaw = data['rank'];
    int? rank;
    if (rankRaw == null) {
      rank = null;
    } else if (rankRaw is int) {
      rank = rankRaw;
    } else if (rankRaw is num) {
      rank = rankRaw.toInt();
    }

    final xpRaw = data['xp_awarded'];
    int? xpAwarded;
    if (xpRaw == null) {
      xpAwarded = null;
    } else if (xpRaw is int) {
      xpAwarded = xpRaw;
    } else if (xpRaw is num) {
      xpAwarded = xpRaw.toInt();
    }

    final ccRaw = data['correct_count'];
    final correctCount = ccRaw is int ?
        ccRaw :
        ccRaw is num ?
            ccRaw.toInt() :
            0;

    final tamRaw = data['total_answer_ms'];
    final totalAnswerMs = tamRaw is int ?
        tamRaw :
        tamRaw is num ?
            tamRaw.toInt() :
            0;

    final xpGrantRaw = data['xp_granted_at'];
    final xpGrantedAt = xpGrantRaw is Timestamp ? xpGrantRaw.toDate() : null;

    final subRaw = data['submitted_at'];
    final submittedAt = subRaw is Timestamp ?
        subRaw.toDate() :
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();

    return LiveResult(
      uid: data['uid'] as String? ?? doc.id,
      correctCount: correctCount,
      totalAnswerMs: totalAnswerMs,
      rank: rank,
      xpAwarded: xpAwarded,
      xpGrantedAt: xpGrantedAt,
      scored: data['scored'] == true,
      submittedAt: submittedAt,
    );
  }
}
