import 'package:cloud_functions/cloud_functions.dart';

enum ReportReason {
  wrongAnswer,
  wrongOrUnclear,
  inappropriateContent,
  other,
}

extension ReportReasonWire on ReportReason {
  String get wireValue => switch (this) {
    ReportReason.wrongAnswer => 'wrong_answer',
    ReportReason.wrongOrUnclear => 'wrong_or_unclear',
    ReportReason.inappropriateContent => 'inappropriate_content',
    ReportReason.other => 'other',
  };
}

enum ReportGameMode {
  daily,
  selfTest,
  arena,
  duel,
  classic,
  live,
}

extension ReportGameModeWire on ReportGameMode {
  String get wireValue => switch (this) {
    ReportGameMode.daily => 'daily',
    ReportGameMode.selfTest => 'self_test',
    ReportGameMode.arena => 'arena',
    ReportGameMode.duel => 'duel',
    ReportGameMode.classic => 'classic',
    ReportGameMode.live => 'live',
  };
}

class ReportServiceException implements Exception {
  ReportServiceException(this.code, this.message);
  final String code;
  final String message;
}

class ReportService {
  ReportService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> submitReport({
    required String questionId,
    required ReportReason reason,
    String? freeText,
    required String timezone,
    required ReportGameMode gameMode,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitReport');
      await callable.call<Map<String, dynamic>>({
        'questionId': questionId,
        'reason': reason.wireValue,
        if (freeText != null && freeText.trim().isNotEmpty) 'freeText': freeText.trim(),
        'timezone': timezone,
        'gameMode': gameMode.wireValue,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ReportServiceException(e.code, e.message ?? 'unknown_error');
    }
  }
}
