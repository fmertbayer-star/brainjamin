import 'package:cloud_firestore/cloud_firestore.dart';

/// Row from `live_questions/{ltId}/q/{qIndex}` (server-written during Live run).
class LiveQuestionData {
  const LiveQuestionData({
    required this.qIndex,
    required this.qId,
    required this.questionText,
    required this.options,
    required this.difficulty,
    required this.category,
    required this.startedAt,
    required this.correctIndex,
  });

  final int qIndex;
  final String qId;
  final String questionText;
  final List<String> options;
  final int difficulty;
  final String category;
  final DateTime startedAt;

  /// Null until server reveal; then 0..3 from Firestore only (never infer locally).
  final int? correctIndex;

  factory LiveQuestionData.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError.value(doc.id, 'doc', 'missing live question data');
    }
    final qIndex = int.tryParse(doc.id);
    if (qIndex == null) {
      throw ArgumentError('invalid live question doc id ${doc.id}');
    }

    final qId = data['q_id'] as String? ?? '';
    final questionText = data['question_text'] as String? ?? '';
    final optionsRaw = data['options'];
    final options = <String>[];
    if (optionsRaw is List) {
      for (final e in optionsRaw) {
        options.add(e?.toString() ?? '');
      }
    }
    while (options.length < 4) {
      options.add('');
    }

    final diffRaw = data['difficulty'];
    final difficulty = diffRaw is int ?
        diffRaw :
        diffRaw is num ?
            diffRaw.toInt() :
            0;

    final category = data['category'] as String? ?? '';

    final startedRaw = data['started_at'];
    if (startedRaw is! Timestamp) {
      throw ArgumentError('missing started_at on live question ${doc.id}');
    }

    final ciRaw = data['correct_index'];
    int? correctIndex;
    if (ciRaw == null) {
      correctIndex = null;
    } else if (ciRaw is int) {
      correctIndex = ciRaw;
    } else if (ciRaw is num) {
      correctIndex = ciRaw.toInt();
    }

    return LiveQuestionData(
      qIndex: qIndex,
      qId: qId,
      questionText: questionText,
      options: options,
      difficulty: difficulty,
      category: category,
      startedAt: startedRaw.toDate(),
      correctIndex: correctIndex,
    );
  }
}
