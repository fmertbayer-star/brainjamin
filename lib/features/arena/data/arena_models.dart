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

  factory ArenaDoc.fromFirestore(String id, Map<String, dynamic> d) {
    final sched = d['scheduled_start_at'];
    DateTime start;
    if (sched is Timestamp) {
      start = sched.toDate();
    } else {
      start = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final ended = d['ended_at'];
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
  });

  final int qIndex;
  final String question;
  final List<String> options;
  final int difficulty;
  final String sourceType;
  final String reportQuestionId;
  final int? correctIndex;

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
    return ArenaQuestionView(
      qIndex: qIndex,
      question: d['question'] as String? ?? '',
      options: list.take(4).toList(),
      difficulty: (d['difficulty'] as num?)?.toInt() ?? 1,
      sourceType: d['source_type'] as String? ?? 'preset',
      reportQuestionId: 'arena_${arenaId}_q$qIndex',
      correctIndex: switch (ci) {
        int v => v,
        final num n => n.toInt(),
        _ => null,
      },
    );
  }
}

final class ArenaLeaderboardEntry {
  const ArenaLeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.correctCount,
    required this.totalRemainingMs,
    required this.score,
  });

  final int rank;
  final String uid;
  final String displayName;
  final int correctCount;
  final int totalRemainingMs;
  final double score;

  factory ArenaLeaderboardEntry.fromMap(Map<String, dynamic> m) {
    return ArenaLeaderboardEntry(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      uid: m['uid'] as String? ?? '',
      displayName: m['display_name'] as String? ?? 'Anonymous Player',
      correctCount: (m['correct_count'] as num?)?.toInt() ?? 0,
      totalRemainingMs: (m['total_remaining_ms'] as num?)?.toInt() ?? 0,
      score: (m['score'] as num?)?.toDouble() ?? 0,
    );
  }
}
