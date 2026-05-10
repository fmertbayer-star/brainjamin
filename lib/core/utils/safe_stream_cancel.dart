import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// [cloud_firestore_web] can throw [LateInitializationError] for
/// `onSnapshotUnsubscribe` when a subscription is cancelled before the first
/// snapshot. Swallow those so navigation does not white-screen on web.
Future<void> safeCancelSubscription(
  StreamSubscription<dynamic>? subscription,
) async {
  if (subscription == null) return;
  try {
    await subscription.cancel();
  } catch (e, stackTrace) {
    debugPrint('Stream cancel error (safe to ignore on web): $e');
    if (kDebugMode) {
      debugPrint('$stackTrace');
    }
  }
}
