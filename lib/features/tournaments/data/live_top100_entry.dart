/// One row from `live_tournaments.top_100` (server-written by finalize).
class LiveTop100Entry {
  const LiveTop100Entry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.correctCount,
    required this.totalAnswerMs,
  });

  final int rank;
  final String uid;

  /// Verbatim from Firestore (`display_name`) — may be `"Anonymous Player"` from backend.
  final String displayName;
  final int correctCount;
  final int totalAnswerMs;

  factory LiveTop100Entry.fromMap(Map<String, dynamic> m) {
    final rankRaw = m['rank'];
    final rank = rankRaw is int ?
        rankRaw :
        rankRaw is num ?
            rankRaw.toInt() :
            0;

    final ccRaw = m['correct_count'];
    final correctCount = ccRaw is int ?
        ccRaw :
        ccRaw is num ?
            ccRaw.toInt() :
            0;

    final tamRaw = m['total_answer_ms'];
    final totalAnswerMs = tamRaw is int ?
        tamRaw :
        tamRaw is num ?
            tamRaw.toInt() :
        0;

    return LiveTop100Entry(
      rank: rank,
      uid: m['uid'] as String? ?? '',
      displayName: m['display_name'] as String? ?? '',
      correctCount: correctCount,
      totalAnswerMs: totalAnswerMs,
    );
  }
}
