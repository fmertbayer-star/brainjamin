import 'package:flutter/foundation.dart';

import '../data/arena_models.dart';
import '../data/arena_service.dart';

enum ArenaQuizStatus {
  idle,
  loading,
  ready,
  submitting,
  submitted,
  error,
}

/// ChangeNotifier state machine for List Arena quiz — mirrors [ClassicQuizController] layout.
final class ArenaQuizController extends ChangeNotifier {
  ArenaQuizController({
    ArenaService? arenaService,
  }) : _arenaService = arenaService ?? ArenaService();

  final ArenaService _arenaService;

  ArenaQuizStatus _status = ArenaQuizStatus.idle;
  ArenaQuizStatus get status => _status;

  String? _error;
  String? get error => _error;

  List<ArenaQuestionView>? _questions;
  List<ArenaQuestionView>? get questions => _questions;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool _revealing = false;
  bool get revealing => _revealing;

  int? _selectedOption;
  int? get selectedOption => _selectedOption;

  final List<Map<String, dynamic>> _answers = [];

  Future<void> load(String arenaId) async {
    _status = ArenaQuizStatus.loading;
    _error = null;
    _questions = null;
    _currentIndex = 0;
    _revealing = false;
    _selectedOption = null;
    _answers.clear();
    notifyListeners();

    try {
      final qs = await _arenaService.getArenaQuestions(arenaId);
      _questions = qs;
      _status = ArenaQuizStatus.ready;
      _error = null;
    } on ArenaServiceException catch (e) {
      _status = ArenaQuizStatus.error;
      _error = e.message;
    } catch (e) {
      _status = ArenaQuizStatus.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Record answer for current question and enter reveal phase (timer already stopped).
  void recordReveal({
    required int selectedOption,
    required int elapsedMs,
  }) {
    if (_status != ArenaQuizStatus.ready || _revealing) {
      return;
    }
    final qs = _questions;
    if (qs == null || _currentIndex >= qs.length) {
      return;
    }
    final qi = qs[_currentIndex].qIndex;
    _answers.removeWhere((m) => (m['q_index'] as int) == qi);
    _answers.add({
      'q_index': qi,
      'selected_option': selectedOption,
      'time_ms': elapsedMs.clamp(0, 15000),
    });
    _selectedOption = selectedOption;
    _revealing = true;
    notifyListeners();
  }

  /// Advance to next question after reveal animation, or submit if last question.
  Future<void> advanceOrSubmit(String arenaId) async {
    final qs = _questions;
    if (qs == null || !_revealing) {
      return;
    }
    if (_currentIndex >= qs.length - 1) {
      await submit(arenaId);
      return;
    }
    _currentIndex += 1;
    _revealing = false;
    _selectedOption = null;
    notifyListeners();
  }

  Future<void> submit(String arenaId) async {
    if (_status != ArenaQuizStatus.ready && _status != ArenaQuizStatus.error) {
      return;
    }
    final qs = _questions;
    if (qs == null || _answers.length != qs.length) {
      _status = ArenaQuizStatus.error;
      _error = 'answers_incomplete';
      notifyListeners();
      return;
    }

    _status = ArenaQuizStatus.submitting;
    _error = null;
    notifyListeners();

    try {
      final sorted = List<Map<String, dynamic>>.from(_answers)
        ..sort(
          (a, b) =>
              (a['q_index'] as int).compareTo(b['q_index'] as int),
        );
      await _arenaService.submitArenaAnswers(
        arenaId: arenaId,
        answers: sorted,
      );
      _status = ArenaQuizStatus.submitted;
    } on ArenaServiceException catch (e) {
      _status = ArenaQuizStatus.error;
      _error = e.message;
      _revealing = false;
    } catch (e) {
      _status = ArenaQuizStatus.error;
      _error = e.toString();
      _revealing = false;
    }
    notifyListeners();
  }

}
