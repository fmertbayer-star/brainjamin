import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class DailyServiceException implements Exception {
  DailyServiceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DailyServiceException($code, $message)';
}

class DailyQuestionState {
  DailyQuestionState({
    required this.dateKey,
    required this.qId,
    required this.questionText,
    required this.options,
    required this.category,
    required this.alreadyAnswered,
    this.selectedIndex,
    this.correctIndex,
    this.isCorrect,
    this.xpAwarded,
    this.submittedAtMs,
  });

  final String dateKey;
  final String qId;
  final String questionText;
  final List<String> options;
  final String category;
  final bool alreadyAnswered;
  final int? selectedIndex;
  final int? correctIndex;
  final bool? isCorrect;
  final int? xpAwarded;
  final int? submittedAtMs;

  factory DailyQuestionState.fromMap(Map<String, dynamic> map) {
    return DailyQuestionState(
      dateKey: map['dateKey'] as String,
      qId: map['qId'] as String,
      questionText: map['questionText'] as String,
      options: List<String>.from(map['options'] as List<dynamic>),
      category: map['category'] as String,
      alreadyAnswered: map['alreadyAnswered'] as bool,
      selectedIndex: map['selectedIndex'] as int?,
      correctIndex: map['correctIndex'] as int?,
      isCorrect: map['isCorrect'] as bool?,
      xpAwarded: map['xpAwarded'] as int?,
      submittedAtMs: map['submittedAtMs'] as int?,
    );
  }
}

class DailyAnswerResult {
  DailyAnswerResult({
    required this.isCorrect,
    required this.correctIndex,
    required this.xpAwarded,
    required this.streak,
    required this.forgivesAvailableThisWeek,
    required this.totalXp,
  });

  final bool isCorrect;
  final int correctIndex;
  final int xpAwarded;
  final int streak;
  final int forgivesAvailableThisWeek;
  final int totalXp;

  factory DailyAnswerResult.fromMap(Map<String, dynamic> map) {
    return DailyAnswerResult(
      isCorrect: map['isCorrect'] as bool,
      correctIndex: map['correctIndex'] as int,
      xpAwarded: map['xpAwarded'] as int,
      streak: map['streak'] as int,
      forgivesAvailableThisWeek: map['forgivesAvailableThisWeek'] as int,
      totalXp: map['totalXp'] as int,
    );
  }
}

class DailyQuestionService {
  DailyQuestionService({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String> detectTimezone() async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    return timezone.identifier;
  }

  Future<DailyQuestionState> selectDailyQuestion({
    required String timezone,
  }) async {
    try {
      final callable = _functions.httpsCallable('selectDailyQuestion');
      final response =
          await callable.call<Map<String, dynamic>>({'timezone': timezone});
      final data = Map<String, dynamic>.from(response.data);
      return DailyQuestionState.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw DailyServiceException(
        e.code,
        (e.message ?? 'unknown_error'),
      );
    }
  }

  Future<DailyAnswerResult> submitDailyAnswer({
    required int selectedIndex,
    required String timezone,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitDailyAnswer');
      final response = await callable.call<Map<String, dynamic>>({
        'selectedIndex': selectedIndex,
        'timezone': timezone,
      });
      final data = Map<String, dynamic>.from(response.data);
      return DailyAnswerResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw DailyServiceException(
        e.code,
        (e.message ?? 'unknown_error'),
      );
    }
  }
}
