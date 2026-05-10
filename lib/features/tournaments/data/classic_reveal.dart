class ClassicRevealQuestion {
  const ClassicRevealQuestion({
    required this.questionId,
    required this.question,
    required this.options,
    required this.category,
    required this.difficulty,
    required this.userAnswerIndex,
    required this.correctIndex,
    required this.isCorrect,
  });

  final String questionId;
  final String question;
  final List<String> options;
  final String category;
  final int difficulty;
  final int? userAnswerIndex;
  final int correctIndex;
  final bool isCorrect;

  factory ClassicRevealQuestion.fromMap(Map<String, dynamic> m) {
    final rawOptions = m['options'];
    if (rawOptions is! List<dynamic>) {
      throw ArgumentError('classic_reveal_question_options_missing');
    }
    return ClassicRevealQuestion(
      questionId: m['questionId'] as String,
      question: m['question'] as String,
      options: rawOptions.cast<String>(),
      category: m['category'] as String,
      difficulty: (m['difficulty'] as num).toInt(),
      userAnswerIndex: m['userAnswerIndex'] as int?,
      correctIndex: (m['correctIndex'] as num).toInt(),
      isCorrect: m['isCorrect'] as bool,
    );
  }
}

class ClassicRevealSessionMeta {
  const ClassicRevealSessionMeta({
    required this.correctCount,
    required this.rank,
    required this.xpAwarded,
    required this.submittedAt,
  });

  final int correctCount;
  final int? rank;
  final int? xpAwarded;
  final DateTime submittedAt;

  factory ClassicRevealSessionMeta.fromMap(Map<String, dynamic> m) {
    return ClassicRevealSessionMeta(
      correctCount: (m['correctCount'] as num).toInt(),
      rank: m['rank'] is num ? (m['rank'] as num).toInt() : null,
      xpAwarded: m['xpAwarded'] is num ? (m['xpAwarded'] as num).toInt() : null,
      submittedAt: _parseFlexibleDate(m['submittedAt']),
    );
  }
}

class ClassicRevealLeaderboardEntry {
  const ClassicRevealLeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.correctCount,
  });

  final int rank;
  final String displayName;
  final int correctCount;

  factory ClassicRevealLeaderboardEntry.fromMap(Map<String, dynamic> m) {
    return ClassicRevealLeaderboardEntry(
      rank: (m['rank'] as num).toInt(),
      displayName: m['displayName'] as String,
      correctCount: (m['correctCount'] as num).toInt(),
    );
  }
}

class ClassicRevealLeaderboardSnippet {
  const ClassicRevealLeaderboardSnippet({
    required this.totalParticipants,
    required this.top10,
  });

  final int totalParticipants;
  final List<ClassicRevealLeaderboardEntry> top10;

  factory ClassicRevealLeaderboardSnippet.fromMap(Map<String, dynamic> m) {
    final rawTop = m['top10'];
    if (rawTop is! List<dynamic>) {
      throw ArgumentError('classic_reveal_top10_missing');
    }
    return ClassicRevealLeaderboardSnippet(
      totalParticipants: (m['totalParticipants'] as num).toInt(),
      top10: rawTop
          .map(
            (e) => ClassicRevealLeaderboardEntry.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class ClassicReveal {
  const ClassicReveal({
    required this.questions,
    required this.sessionMeta,
    required this.leaderboardSnippet,
  });

  final List<ClassicRevealQuestion> questions;
  final ClassicRevealSessionMeta sessionMeta;
  final ClassicRevealLeaderboardSnippet? leaderboardSnippet;

  factory ClassicReveal.fromMap(Map<String, dynamic> m) {
    final rawQuestions = m['questions'];
    if (rawQuestions is! List<dynamic>) {
      throw ArgumentError('classic_reveal_questions_missing');
    }
    return ClassicReveal(
      questions: rawQuestions
          .map(
            (e) => ClassicRevealQuestion.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      sessionMeta: ClassicRevealSessionMeta.fromMap(
        Map<String, dynamic>.from(m['sessionMeta'] as Map),
      ),
      leaderboardSnippet: m['leaderboardSnippet'] == null ?
          null :
          ClassicRevealLeaderboardSnippet.fromMap(
            Map<String, dynamic>.from(m['leaderboardSnippet'] as Map),
          ),
    );
  }
}

DateTime _parseFlexibleDate(dynamic v) {
  if (v is DateTime) {
    return v;
  }
  if (v is String) {
    return DateTime.parse(v);
  }
  if (v is Map) {
    final seconds = v['_seconds'] ?? v['seconds'];
    final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanos is int ? nanos ~/ 1000000 : 0),
        isUtc: true,
      ).toLocal();
    }
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
  }
  throw ArgumentError('classic_reveal_submitted_at_invalid');
}
