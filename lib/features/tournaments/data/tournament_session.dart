import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentSession {
  const TournamentSession({
    required this.sessionId,
    required this.slotId,
    required this.uid,
    required this.status,
    this.correctCount,
    this.submittedAt,
    this.rank,
    this.xpAwarded,
  });

  final String sessionId;
  final String slotId;
  final String uid;
  final String status;
  final int? correctCount;
  final DateTime? submittedAt;
  final int? rank;
  final int? xpAwarded;

  factory TournamentSession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError.value(doc.id, 'doc', 'missing session data');
    }
    final submittedAtTs = data['submitted_at'];
    final cc = data['correct_count'];
    final rk = data['rank'];
    final xp = data['xp_awarded'];

    return TournamentSession(
      sessionId: doc.id,
      slotId: data['slot_id'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      status: data['status'] as String? ?? '',
      correctCount: cc is int ?
          cc :
          cc is num ?
              cc.toInt() :
              null,
      submittedAt: submittedAtTs is Timestamp ?
          submittedAtTs.toDate() :
          null,
      rank: rk is int ?
          rk :
          rk is num ?
              rk.toInt() :
              null,
      xpAwarded: xp is int ?
          xp :
          xp is num ?
              xp.toInt() :
              null,
    );
  }

  bool get isInProgress => status == 'in_progress';

  bool get isSubmitted => status == 'submitted';

  bool get isFinalized => isSubmitted && rank != null;
}
