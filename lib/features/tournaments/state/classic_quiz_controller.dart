import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../data/classic_quiz_draft.dart';
import '../data/classic_quiz_question.dart';
import '../services/classic_quiz_draft_service.dart';
import '../services/tournament_callables.dart';

enum ClassicQuizStatus {
  idle,
  loading,
  ready,
  submitting,
  submitted,
  alreadySubmitted,
  error,
}

class ClassicQuizController extends ChangeNotifier {
  ClassicQuizController({
    required this.slotId,
    required this.uid,
    TournamentCallables? callables,
    ClassicQuizDraftService? draftService,
  })  : _callables = callables ?? TournamentCallables(),
        _draftService = draftService ?? ClassicQuizDraftService();

  final String slotId;
  final String uid;

  final TournamentCallables _callables;
  final ClassicQuizDraftService _draftService;

  ClassicQuizStatus _status = ClassicQuizStatus.idle;
  ClassicQuizStatus get status => _status;

  String? _error;
  String? get error => _error;

  List<ClassicQuizQuestion>? _questions;
  List<ClassicQuizQuestion>? get questions => _questions;

  ClassicQuizDraft? _draft;
  ClassicQuizDraft? get draft => _draft;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool get isSubmitting => _status == ClassicQuizStatus.submitting;

  int? _submittedCorrectCount;
  int? get submittedCorrectCount => _submittedCorrectCount;

  DateTime? _submittedAt;
  DateTime? get submittedAt => _submittedAt;

  Future<void> start() async {
    if (uid.isEmpty) {
      _status = ClassicQuizStatus.error;
      _error = 'auth_required';
      notifyListeners();
      return;
    }

    _status = ClassicQuizStatus.loading;
    _error = null;
    _questions = null;
    _draft = null;
    notifyListeners();

    try {
      final result = await _callables.getClassicTournamentQuestions(slotId);

      if (result.sessionStatus == 'submitted') {
        _status = ClassicQuizStatus.alreadySubmitted;
        notifyListeners();
        return;
      }

      if (result.questions.length != 20) {
        throw StateError(
          'Expected 20 questions, got ${result.questions.length}',
        );
      }

      _questions = result.questions;

      var loaded = await _draftService.load(slotId, uid);
      if (loaded == null || loaded.slotId != slotId) {
        loaded = ClassicQuizDraft.empty(slotId);
      }

      _draft = loaded;

      final firstNull = loaded.answers.indexWhere((a) => a == null);
      _currentIndex = firstNull == -1 ? 19 : firstNull.clamp(0, 19);

      _status = ClassicQuizStatus.ready;
      _error = null;
    } on FirebaseFunctionsException catch (e) {
      _status = ClassicQuizStatus.error;
      _error = _mapFunctionsMessage(e);
    } catch (e) {
      _status = ClassicQuizStatus.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  String _mapFunctionsMessage(FirebaseFunctionsException e) {
    final code = e.code;
    final msg = e.message ?? '';
    if (code == 'failed-precondition') {
      return 'window_closed';
    }
    return msg.isNotEmpty ? msg : code;
  }

  Future<void> selectOption(int optionIndex) async {
    if (_status != ClassicQuizStatus.ready || _draft == null || _questions == null) {
      return;
    }
    if (optionIndex < 0 || optionIndex > 3) {
      return;
    }

    final nextAnswers = List<int?>.from(_draft!.answers);
    nextAnswers[_currentIndex] = optionIndex;
    _draft = ClassicQuizDraft(
      slotId: slotId,
      answers: nextAnswers,
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    unawaited(
      _draftService.save(_draft!, uid).catchError((Object e) {
        if (kDebugMode) {
          debugPrint('ClassicQuiz draft save failed: $e');
        }
      }),
    );
  }

  void next() {
    if (_currentIndex < 19) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void jumpTo(int idx) {
    _currentIndex = idx.clamp(0, 19);
    notifyListeners();
  }

  Future<void> submit() async {
    final d = _draft;
    if (d == null || !d.isComplete || _status != ClassicQuizStatus.ready) {
      return;
    }

    _status = ClassicQuizStatus.submitting;
    notifyListeners();

    final payload = List<int>.generate(20, (i) => d.answers[i]!);

    try {
      final result = await _callables.submitClassicTournamentAnswers(
        slotId: slotId,
        answers: payload,
      );
      _submittedCorrectCount = result.correctCount;
      _submittedAt = result.submittedAt;
      await _draftService.clear(slotId, uid);
      _status = ClassicQuizStatus.submitted;
      _error = null;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        _status = ClassicQuizStatus.alreadySubmitted;
        _error = null;
      } else if (e.code == 'failed-precondition') {
        _status = ClassicQuizStatus.error;
        _error = 'window_closed';
      } else {
        _status = ClassicQuizStatus.error;
        _error = e.message ?? e.code;
      }
    } catch (e) {
      _status = ClassicQuizStatus.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  bool get isWindowClosedError => _error == 'window_closed';
}
