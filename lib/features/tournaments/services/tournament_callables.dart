import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/firebase_config.dart';
import '../data/classic_reveal.dart';
import '../data/classic_quiz_question.dart';

/// HTTPS callable gateway for Classic tournament Cloud Functions.
final class TournamentCallables {
  TournamentCallables({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion);

  final FirebaseFunctions _functions;

  Future<ClassicQuestionsResult> getClassicTournamentQuestions(
    String slotId,
  ) async {
    final callable = _functions.httpsCallable('getClassicTournamentQuestions');
    final response =
        await callable.call<Map<String, dynamic>>({'slotId': slotId.trim()});
    final data = Map<String, dynamic>.from(response.data);
    final rawQs = data['questions'];
    if (rawQs is! List<dynamic>) {
      throw StateError('getClassicTournamentQuestions: missing questions');
    }
    final questions = rawQs
        .map(
          (e) => ClassicQuizQuestion.fromCallableMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    final sessionStatus = data['sessionStatus'] as String? ?? '';
    return ClassicQuestionsResult(
      questions: questions,
      sessionStatus: sessionStatus,
    );
  }

  Future<ClassicSubmitResult> submitClassicTournamentAnswers({
    required String slotId,
    required List<int> answers,
  }) async {
    final callable =
        _functions.httpsCallable('submitClassicTournamentAnswers');
    final response = await callable.call<Map<String, dynamic>>({
      'slotId': slotId.trim(),
      'answers': answers,
    });
    final data = Map<String, dynamic>.from(response.data);
    final correctCount = data['correctCount'];
    final sessionStatus = data['sessionStatus'] as String? ?? 'submitted';
    final submittedRaw = data['submittedAt'];
    return ClassicSubmitResult(
      correctCount: correctCount is int ?
          correctCount :
          (correctCount is num ? correctCount.toInt() : 0),
      sessionStatus: sessionStatus,
      submittedAt: _parseSubmittedAt(submittedRaw),
    );
  }

  Future<ClassicReveal> getClassicTournamentReveal(String slotId) async {
    final callable = _functions.httpsCallable('getClassicTournamentReveal');
    final result =
        await callable.call<Map<String, dynamic>>({'slotId': slotId.trim()});
    return ClassicReveal.fromMap(Map<String, dynamic>.from(result.data));
  }
}

DateTime _parseSubmittedAt(dynamic v) {
  if (v == null) {
    return DateTime.now();
  }
  if (v is DateTime) {
    return v;
  }
  // ignore: avoid_dynamic_calls
  if (v is Map) {
    final seconds = v['_seconds'] ?? v['seconds'];
    final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
    if (seconds is int) {
      final ms = seconds * 1000 + (nanos is int ? nanos ~/ 1000000 : 0);
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
  }
  if (v is String) {
    return DateTime.parse(v);
  }
  return DateTime.now();
}

class ClassicQuestionsResult {
  const ClassicQuestionsResult({
    required this.questions,
    required this.sessionStatus,
  });

  final List<ClassicQuizQuestion> questions;
  final String sessionStatus;
}

class ClassicSubmitResult {
  const ClassicSubmitResult({
    required this.correctCount,
    required this.sessionStatus,
    required this.submittedAt,
  });

  final int correctCount;
  final String sessionStatus;
  final DateTime submittedAt;
}
