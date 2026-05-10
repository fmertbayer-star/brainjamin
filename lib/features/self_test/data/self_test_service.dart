import 'package:cloud_functions/cloud_functions.dart';

enum SelfTestErrorCode {
  insufficientPool,
  unknown,
}

class SelfTestServiceException implements Exception {
  SelfTestServiceException(
    this.code,
    this.message, {
    this.errorCode = SelfTestErrorCode.unknown,
  });

  final String code;
  final String message;
  final SelfTestErrorCode errorCode;

  @override
  String toString() => 'SelfTestServiceException($code, $message)';
}

class SelfTestQuestion {
  SelfTestQuestion({
    required this.qId,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.category,
    required this.difficulty,
  });

  final String qId;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String category;
  final int difficulty;

  factory SelfTestQuestion.fromMap(Map<String, dynamic> map) {
    return SelfTestQuestion(
      qId: map['qId'] as String,
      questionText: map['questionText'] as String,
      options: List<String>.from(map['options'] as List<dynamic>),
      correctIndex: map['correctIndex'] as int,
      category: map['category'] as String,
      difficulty: map['difficulty'] as int,
    );
  }
}

class SelfTestSessionData {
  SelfTestSessionData({
    required this.sessionId,
    required this.questions,
  });

  final String sessionId;
  final List<SelfTestQuestion> questions;

  factory SelfTestSessionData.fromMap(Map<String, dynamic> map) {
    final raw = map['questions'];
    if (raw is! List<dynamic>) {
      throw SelfTestServiceException(
        'invalid_response',
        'missing_questions',
      );
    }
    return SelfTestSessionData(
      sessionId: map['sessionId'] as String,
      questions: raw
          .map((e) => SelfTestQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class SelfTestSubmitResult {
  SelfTestSubmitResult({
    required this.correctCount,
    required this.totalRemainingMs,
    required this.weekKey,
  });

  final int correctCount;
  final int totalRemainingMs;
  final String weekKey;

  factory SelfTestSubmitResult.fromMap(Map<String, dynamic> map) {
    return SelfTestSubmitResult(
      correctCount: map['correctCount'] as int,
      totalRemainingMs: map['totalRemainingMs'] as int,
      weekKey: map['weekKey'] as String,
    );
  }
}

class SelfTestService {
  SelfTestService({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<SelfTestSessionData> selectSelfTestQuestions() async {
    try {
      final callable = _functions.httpsCallable('selectSelfTestQuestions');
      final response =
          await callable.call<Map<String, dynamic>>(<String, dynamic>{});
      final data = Map<String, dynamic>.from(response.data);
      return SelfTestSessionData.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsException(e);
    }
  }

  Future<SelfTestSubmitResult> submitSelfTestSession({
    required String sessionId,
    required List<int> answers,
    required List<int> perQuestionRemainingMs,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitSelfTestSession');
      final response = await callable.call<Map<String, dynamic>>({
        'sessionId': sessionId,
        'answers': answers,
        'perQuestionRemainingMs': perQuestionRemainingMs,
      });
      final data = Map<String, dynamic>.from(response.data);
      return SelfTestSubmitResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw _mapFunctionsException(e);
    }
  }

  Never _mapFunctionsException(FirebaseFunctionsException e) {
    final msg = e.message ?? '';
    final code = e.code;
    if (code == 'failed-precondition' &&
        (msg == 'self_test_insufficient_pool' ||
            msg.contains('self_test_insufficient_pool'))) {
      throw SelfTestServiceException(
        code,
        msg,
        errorCode: SelfTestErrorCode.insufficientPool,
      );
    }
    throw SelfTestServiceException(code, msg);
  }
}
