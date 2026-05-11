import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical V1 category ids — mirrors `functions/src/shared/categories.ts`.
const List<String> kV1CategoryIds = [
  'history',
  'geography',
  'movies_tv',
  'music',
  'sports',
  'science',
  'technology',
  'literature',
  'art',
  'food_drink',
  'animals',
  'nature',
  'pop_culture',
  'mythology',
  'video_games',
  'fashion',
  'astrology',
  'health',
  'space',
  'world_capitals',
];

/// Arena document `arenas/{arenaId}` (subset used by UI).
final class ArenaDoc {
  const ArenaDoc({
    required this.id,
    required this.mode,
    required this.status,
    required this.sourceType,
    this.name,
    this.categoryId,
    this.customTopic,
    required this.inviteCode,
    required this.scheduledStartAt,
    required this.participantCount,
    required this.creatorId,
    this.endedAt,
    this.currentQuestion,
    this.revealActive,
    this.lateJoinClosed,
    this.finalizedAt,
    this.topHundred,
    this.totalFinalizedParticipants,
  });

  final String id;
  final String mode;
  final String status;
  final String sourceType;
  final String? name;
  final String? categoryId;
  final String? customTopic;
  final String inviteCode;
  final DateTime scheduledStartAt;
  final int participantCount;
  final String creatorId;
  final DateTime? endedAt;

  /// Server-driven question index (0..9) while `status == running`.
  final int? currentQuestion;

  final bool? revealActive;
  final bool? lateJoinClosed;
  final DateTime? finalizedAt;

  /// Duplicated on the arena doc after finalize (same shape as `arena_leaderboards`).
  final List<ArenaLeaderboardEntry>? topHundred;

  final int? totalFinalizedParticipants;

  bool get isTerminal =>
      status == 'ended' ||
      status == 'no_participants' ||
      status == 'generation_failed';

  factory ArenaDoc.fromFirestore(String id, Map<String, dynamic> d) {
    final sched = d['scheduled_start_at'];
    DateTime start;
    if (sched is Timestamp) {
      start = sched.toDate();
    } else {
      start = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final ended = d['ended_at'];
    final finalized = d['finalized_at'];
    final cqRaw = d['current_question'];
    int? currentQuestion;
    if (cqRaw is int) {
      currentQuestion = cqRaw;
    } else if (cqRaw is num) {
      currentQuestion = cqRaw.toInt();
    }

    List<ArenaLeaderboardEntry>? topHundred;
    final rawTop = d['top_100'];
    if (rawTop is List) {
      topHundred = rawTop
          .whereType<Map>()
          .map(
            (e) => ArenaLeaderboardEntry.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    }

    return ArenaDoc(
      id: id,
      mode: d['mode'] as String? ?? 'list',
      status: d['status'] as String? ?? 'preparing',
      sourceType: d['source_type'] as String? ?? 'preset',
      name: d['name'] as String?,
      categoryId: d['category_id'] as String?,
      customTopic: d['custom_topic'] as String?,
      inviteCode: d['invite_code'] as String? ?? '',
      scheduledStartAt: start,
      participantCount: (d['participant_count'] as num?)?.toInt() ?? 0,
      creatorId: d['creator_id'] as String? ?? '',
      endedAt: ended is Timestamp ? ended.toDate() : null,
      currentQuestion: currentQuestion,
      revealActive: d['reveal_active'] as bool?,
      lateJoinClosed: d['late_join_closed'] as bool?,
      finalizedAt: finalized is Timestamp ? finalized.toDate() : null,
      topHundred: topHundred,
      totalFinalizedParticipants:
          (d['total_finalized_participants'] as num?)?.toInt(),
    );
  }
}

final class ArenaParticipant {
  const ArenaParticipant({
    required this.uid,
    required this.joinedAt,
    required this.isCreator,
    required this.status,
    this.displayName,
    this.correctCount,
    this.totalRemainingMs,
    this.score,
    this.rank,
    this.xpAwarded,
  });

  final String uid;
  final DateTime joinedAt;
  final bool isCreator;
  final String status;
  final String? displayName;
  final int? correctCount;
  final int? totalRemainingMs;
  final double? score;
  final int? rank;
  final int? xpAwarded;

  factory ArenaParticipant.fromFirestore(String uid, Map<String, dynamic> d) {
    final ja = d['joined_at'];
    return ArenaParticipant(
      uid: uid,
      joinedAt: ja is Timestamp ? ja.toDate() : DateTime.now(),
      isCreator: d['is_creator'] == true,
      status: d['status'] as String? ?? 'joined',
      displayName: null,
      correctCount: (d['correct_count'] as num?)?.toInt(),
      totalRemainingMs: (d['total_remaining_ms'] as num?)?.toInt(),
      score: (d['score'] as num?)?.toDouble(),
      rank: (d['rank'] as num?)?.toInt(),
      xpAwarded: (d['xp_awarded'] as num?)?.toInt(),
    );
  }
}

final class ArenaQuestionView {
  const ArenaQuestionView({
    required this.qIndex,
    required this.question,
    required this.options,
    required this.difficulty,
    required this.sourceType,
    required this.reportQuestionId,
    this.correctIndex,
    this.startedAt,
    this.correctIndexServer,
  });

  final int qIndex;
  final String question;
  final List<String> options;
  final int difficulty;
  final String sourceType;
  final String reportQuestionId;

  /// Null until server reveal; then 0..3.
  final int? correctIndex;

  final DateTime? startedAt;

  /// Optional trusted field from the server (UI may ignore).
  final int? correctIndexServer;

  factory ArenaQuestionView.fromFirestore(
    String arenaId,
    int qIndex,
    Map<String, dynamic> d,
  ) {
    final opts = d['options'];
    final list = opts is List ? opts.map((e) => '$e').toList() : <String>[];
    while (list.length < 4) {
      list.add('');
    }
    final ci = d['correct_index'];
    int? correctIndex;
    if (ci != null) {
      if (ci is int) {
        correctIndex = ci;
      } else if (ci is num) {
        correctIndex = ci.toInt();
      }
    }

    final cis = d['correct_index_server'];
    int? correctIndexServer;
    if (cis is int) {
      correctIndexServer = cis;
    } else if (cis is num) {
      correctIndexServer = cis.toInt();
    }

    final started = d['started_at'];
    return ArenaQuestionView(
      qIndex: qIndex,
      question: d['question'] as String? ?? '',
      options: list.take(4).toList(),
      difficulty: (d['difficulty'] as num?)?.toInt() ?? 1,
      sourceType: d['source_type'] as String? ?? 'preset',
      reportQuestionId: 'arena_${arenaId}_q$qIndex',
      correctIndex: correctIndex,
      startedAt: started is Timestamp ? started.toDate() : null,
      correctIndexServer: correctIndexServer,
    );
  }
}

/// One row sent to `submitArenaAnswers` (snake_case in JSON).
final class ArenaAnswerInput {
  const ArenaAnswerInput({
    required this.qIndex,
    required this.selectedIndex,
    required this.submittedAtMs,
  });

  final int qIndex;

  /// Null if not answered, -1 if skipped, 0..3 if chosen.
  final int? selectedIndex;
  final int submittedAtMs;
}

/// Callable `submitArenaAnswers` success payload (subset).
final class ArenaSubmitResult {
  const ArenaSubmitResult({
    required this.arenaId,
    required this.correctCount,
    required this.totalAnswerMs,
    required this.scored,
  });

  final String arenaId;
  final int correctCount;
  final int totalAnswerMs;
  final bool scored;
}

/// User row under `arena_results/{arenaId}/users/{uid}`.
final class ArenaMyResult {
  const ArenaMyResult({
    required this.uid,
    required this.correctCount,
    required this.totalAnswerMs,
    required this.rank,
    required this.xpAwarded,
    required this.scored,
  });

  final String uid;
  final int correctCount;
  final int totalAnswerMs;
  final int? rank;
  final int? xpAwarded;
  final bool scored;

  factory ArenaMyResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError.value(doc.id, 'doc', 'missing arena result data');
    }
    final ccRaw = data['correct_count'];
    final correctCount = ccRaw is int
        ? ccRaw
        : ccRaw is num
            ? ccRaw.toInt()
            : 0;
    final tamRaw = data['total_answer_ms'];
    final totalAnswerMs = tamRaw is int
        ? tamRaw
        : tamRaw is num
            ? tamRaw.toInt()
            : 0;
    final rankRaw = data['rank'];
    int? rank;
    if (rankRaw is int) {
      rank = rankRaw;
    } else if (rankRaw is num) {
      rank = rankRaw.toInt();
    }
    final xpRaw = data['xp_awarded'];
    int? xpAwarded;
    if (xpRaw is int) {
      xpAwarded = xpRaw;
    } else if (xpRaw is num) {
      xpAwarded = xpRaw.toInt();
    }
    return ArenaMyResult(
      uid: data['uid'] as String? ?? doc.id,
      correctCount: correctCount,
      totalAnswerMs: totalAnswerMs,
      rank: rank,
      xpAwarded: xpAwarded,
      scored: data['scored'] == true,
    );
  }
}

final class ArenaLeaderboardEntry {
  const ArenaLeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.correctCount,
    required this.totalAnswerMs,
    this.totalRemainingMs,
    this.score,
  });

  final int rank;
  final String uid;
  final String displayName;
  final int correctCount;

  /// Post-finalize scoring field (lower is faster).
  final int totalAnswerMs;

  /// Legacy field on older rollup rows (optional).
  final int? totalRemainingMs;
  final double? score;

  factory ArenaLeaderboardEntry.fromMap(Map<String, dynamic> m) {
    final tam = (m['total_answer_ms'] as num?)?.toInt();
    final trm = (m['total_remaining_ms'] as num?)?.toInt();
    final totalAnswerMs = tam ?? trm ?? 0;
    return ArenaLeaderboardEntry(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      uid: m['uid'] as String? ?? '',
      displayName: m['display_name'] as String? ?? 'Anonymous Player',
      correctCount: (m['correct_count'] as num?)?.toInt() ?? 0,
      totalAnswerMs: totalAnswerMs,
      totalRemainingMs: trm,
      score: (m['score'] as num?)?.toDouble(),
    );
  }
}
