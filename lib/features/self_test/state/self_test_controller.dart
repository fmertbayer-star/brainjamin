import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/self_test_service.dart';

enum SelfTestStatus {
  idle,
  loading,
  inProgress,
  submitting,
  completed,
  error,
}

class SelfTestController extends ChangeNotifier {
  SelfTestController({
    required SelfTestService service,
  }) : _service = service;

  final SelfTestService _service;

  SelfTestStatus _status = SelfTestStatus.idle;
  SelfTestStatus get status => _status;

  SelfTestSessionData? _session;
  SelfTestSessionData? get session => _session;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  List<int?> _answers = List<int?>.filled(25, null, growable: false);
  List<int?> get answers => List<int?>.unmodifiable(_answers);

  List<int> _perQuestionRemainingMs =
      List<int>.filled(25, 0, growable: false);
  List<int> get perQuestionRemainingMs =>
      List<int>.unmodifiable(_perQuestionRemainingMs);

  SelfTestSubmitResult? _result;
  SelfTestSubmitResult? get result => _result;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  SelfTestErrorCode? _errorCode;
  SelfTestErrorCode? get errorCode => _errorCode;

  Future<void> startSession() async {
    _status = SelfTestStatus.loading;
    _errorMessage = null;
    _errorCode = null;
    _session = null;
    _result = null;
    _currentIndex = 0;
    notifyListeners();

    try {
      final data = await _service.selectSelfTestQuestions();
      _session = data;
      _answers = List<int?>.filled(25, null, growable: false);
      _perQuestionRemainingMs = List<int>.filled(25, 0, growable: false);
      _currentIndex = 0;
      _status = SelfTestStatus.inProgress;
    } on SelfTestServiceException catch (e) {
      _status = SelfTestStatus.error;
      _errorMessage = e.message;
      _errorCode = e.errorCode;
    } catch (_) {
      _status = SelfTestStatus.error;
      _errorMessage = 'unknown_error';
      _errorCode = SelfTestErrorCode.unknown;
    }
    notifyListeners();
  }

  void answerCurrent(int selectedIndex, int remainingMs) {
    if (_status != SelfTestStatus.inProgress) {
      return;
    }
    _answers[_currentIndex] = selectedIndex;
    _perQuestionRemainingMs[_currentIndex] = remainingMs.clamp(0, 10000);
    notifyListeners();
  }

  void advance() {
    if (_status != SelfTestStatus.inProgress) {
      return;
    }
    if (_currentIndex < 24) {
      _currentIndex++;
      notifyListeners();
      return;
    }
    if (_currentIndex == 24) {
      _status = SelfTestStatus.submitting;
      notifyListeners();
      unawaited(submitSession());
    }
  }

  Future<void> submitSession() async {
    if (_session == null) {
      return;
    }
    try {
      final answersOut =
          _answers.map((e) => e ?? -1).toList(growable: false);
      final result = await _service.submitSelfTestSession(
        sessionId: _session!.sessionId,
        answers: answersOut,
        perQuestionRemainingMs: List<int>.from(_perQuestionRemainingMs),
      );
      _result = result;
      _status = SelfTestStatus.completed;
    } on SelfTestServiceException catch (e) {
      _status = SelfTestStatus.error;
      _errorMessage = e.message;
      _errorCode = e.errorCode;
    } catch (_) {
      _status = SelfTestStatus.error;
      _errorMessage = 'unknown_error';
      _errorCode = SelfTestErrorCode.unknown;
    }
    notifyListeners();
  }

  void reset() {
    _status = SelfTestStatus.idle;
    _session = null;
    _currentIndex = 0;
    _answers = List<int?>.filled(25, null, growable: false);
    _perQuestionRemainingMs = List<int>.filled(25, 0, growable: false);
    _result = null;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }
}
