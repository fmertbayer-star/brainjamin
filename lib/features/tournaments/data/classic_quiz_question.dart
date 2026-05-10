class ClassicQuizQuestion {
  const ClassicQuizQuestion({
    required this.questionId,
    required this.question,
    required this.options,
    required this.category,
    required this.difficulty,
  });

  final String questionId;
  final String question;
  final List<String> options;
  final String category;
  final int difficulty;

  factory ClassicQuizQuestion.fromCallableMap(Map<String, dynamic> m) {
    final opts = (m['options'] as List<dynamic>).cast<String>();
    if (opts.length != 4) {
      throw ArgumentError('Expected 4 options, got ${opts.length}');
    }
    return ClassicQuizQuestion(
      questionId: m['questionId'] as String,
      question: m['question'] as String,
      options: opts,
      category: m['category'] as String,
      difficulty: (m['difficulty'] as num).toInt(),
    );
  }
}
