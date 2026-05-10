import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/classic_quiz_draft.dart';

/// Local draft persistence for Classic tournament quiz (24h async window).
final class ClassicQuizDraftService {
  ClassicQuizDraftService();

  String _key(String slotId, String uid) =>
      'brainjamin.tournament.draft.$slotId.$uid';

  Future<ClassicQuizDraft?> load(String slotId, String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(slotId, uid));
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        return null;
      }
      return ClassicQuizDraft.fromJson(map);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ClassicQuizDraftService.load failed: $e\n$st');
      }
      return null;
    }
  }

  Future<void> save(ClassicQuizDraft draft, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(draft.slotId, uid),
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> clear(String slotId, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(slotId, uid));
  }
}
