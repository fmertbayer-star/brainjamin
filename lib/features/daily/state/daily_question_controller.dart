import 'package:flutter/foundation.dart';

import '../data/daily_question_service.dart';

enum DailyQuestionStatus {
  idle,
  loading,
  ready,
  answered,
  error,
}

class DailyQuestionController extends ChangeNotifier {
  DailyQuestionController({
    required DailyQuestionService service,
  }) : _service = service;

  final DailyQuestionService _service;

  DailyQuestionStatus _status = DailyQuestionStatus.idle;
  DailyQuestionStatus get status => _status;

  DailyQuestionState? _question;
  DailyQuestionState? get question => _question;

  DailyAnswerResult? _answerResult;
  DailyAnswerResult? get answerResult => _answerResult;

  int? _streak;
  int? get streak => _streak;

  int? _forgivesAvailableThisWeek;
  int? get forgivesAvailableThisWeek => _forgivesAvailableThisWeek;

  String? _timezone;
  String? get timezone => _timezone;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorCode;
  String? get errorCode => _errorCode;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _status = DailyQuestionStatus.loading;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _timezone ??= await _service.detectTimezone();
      final selected = await _service.selectDailyQuestion(timezone: _timezone!);
      _question = selected;
      _status = selected.alreadyAnswered ?
        DailyQuestionStatus.answered :
        DailyQuestionStatus.ready;
    } on DailyServiceException catch (e) {
      _status = DailyQuestionStatus.error;
      _errorCode = e.code;
      _errorMessage = e.message;
    } catch (_) {
      _status = DailyQuestionStatus.error;
      _errorCode = 'unknown';
      _errorMessage = 'unknown_error';
    }
    notifyListeners();
  }

  Future<void> submit(int selectedIndex) async {
    if (_question == null || _isSubmitting || _timezone == null) {
      return;
    }
    _isSubmitting = true;
    notifyListeners();

    try {
      _answerResult = await _service.submitDailyAnswer(
        selectedIndex: selectedIndex,
        timezone: _timezone!,
      );
      _streak = _answerResult!.streak;
      _forgivesAvailableThisWeek = _answerResult!.forgivesAvailableThisWeek;
      final refreshed = await _service.selectDailyQuestion(timezone: _timezone!);
      _question = refreshed;
      _status = DailyQuestionStatus.answered;
      _errorCode = null;
      _errorMessage = null;
    } on DailyServiceException catch (e) {
      _status = DailyQuestionStatus.error;
      _errorCode = e.code;
      _errorMessage = e.message;
    } catch (_) {
      _status = DailyQuestionStatus.error;
      _errorCode = 'unknown';
      _errorMessage = 'unknown_error';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
