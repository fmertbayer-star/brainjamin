class ClassicQuizDraft {
  const ClassicQuizDraft({
    required this.slotId,
    required this.answers,
    required this.updatedAt,
  });

  final String slotId;
  final List<int?> answers;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'answers': answers,
        'updatedAtIso': updatedAt.toIso8601String(),
      };

  factory ClassicQuizDraft.fromJson(Map<String, dynamic> j) {
    final raw = j['answers'];
    if (raw is! List<dynamic>) {
      throw ArgumentError('Draft answers missing');
    }
    final answers = <int?>[];
    for (final e in raw) {
      if (e == null) {
        answers.add(null);
      } else if (e is int) {
        answers.add(e);
      } else if (e is num) {
        answers.add(e.toInt());
      } else {
        throw ArgumentError('Invalid answer cell: $e');
      }
    }
    if (answers.length != 20) {
      throw ArgumentError(
        'Draft answers length must be 20, got ${answers.length}',
      );
    }
    return ClassicQuizDraft(
      slotId: j['slotId'] as String,
      answers: answers,
      updatedAt: DateTime.parse(j['updatedAtIso'] as String),
    );
  }

  factory ClassicQuizDraft.empty(String slotId, {DateTime? now}) =>
      ClassicQuizDraft(
        slotId: slotId,
        answers: List<int?>.filled(20, null),
        updatedAt: now ?? DateTime.now(),
      );

  bool get isComplete => !answers.contains(null);

  int get answeredCount => answers.where((a) => a != null).length;
}
