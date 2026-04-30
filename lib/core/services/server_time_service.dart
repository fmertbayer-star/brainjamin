import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// PR-10: Authoritative client clock for scoring, streaks, game timing, and
/// state transitions. Use [now] in those paths — raw [DateTime.now] is forbidden
/// there. Cosmetic UI (e.g. relative "updated ago" labels) may still use local time.
final class ServerTimeService {
  ServerTimeService._();

  static int _offsetMs = 0;
  static bool _initialized = false;

  static int get offsetMs => _offsetMs;

  static bool get isInitialized => _initialized;

  /// Reads Firebase RTDB `.info/serverTimeOffset` once at startup (5s timeout).
  /// On failure, offset stays 0; initialization still completes.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('.info/serverTimeOffset')
          .get()
          .timeout(const Duration(seconds: 5));
      final value = snapshot.value;
      if (value is num) {
        _offsetMs = value.round();
      } else {
        _offsetMs = 0;
      }
    } catch (_) {
      _offsetMs = 0;
    }
    _initialized = true;
    if (kDebugMode) {
      debugPrint('[ServerTimeService] offset=${_offsetMs}ms');
    }
  }

  /// Server-adjusted local time for gameplay and countdown UI.
  static DateTime now() {
    return DateTime.now()
        .toUtc()
        .add(Duration(milliseconds: _offsetMs))
        .toLocal();
  }
}
