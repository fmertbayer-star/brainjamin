import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/server_time_service.dart';

/// Classic / future Live tournament row from `tournaments/{slotId}`.
class Tournament {
  const Tournament({
    required this.slotId,
    required this.slotKey,
    required this.mode,
    required this.status,
    required this.categoryId,
    required this.startsAt,
    required this.endsAt,
    required this.generatedCount,
    required this.qIds,
  });

  final String slotId;
  final String slotKey;
  final String mode;
  final String status;
  final String categoryId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int generatedCount;
  final List<String> qIds;

  bool get isVisible => status == 'visible';

  /// Visible window only — uses server-adjusted clock (no [DateTime.now]).
  bool get isActive {
    if (!isVisible) {
      return false;
    }
    final now = ServerTimeService.now();
    return !startsAt.isAfter(now) && !endsAt.isBefore(now);
  }

  bool get isEnded => status == 'ended';

  factory Tournament.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError.value(doc.id, 'doc', 'missing tournament data');
    }
    final sid = data['slot_id'] as String? ?? doc.id;
    final st = data['status'] as String?;
    final cat = data['category_id'] as String?;
    if (st == null || st.isEmpty) {
      throw ArgumentError('missing status on tournament ${doc.id}');
    }
    if (cat == null || cat.isEmpty) {
      throw ArgumentError('missing category_id on tournament ${doc.id}');
    }

    final startsRaw = data['starts_at'];
    final endsRaw = data['ends_at'];
    if (startsRaw is! Timestamp || endsRaw is! Timestamp) {
      throw ArgumentError('missing starts_at / ends_at on tournament ${doc.id}');
    }

    final qRaw = data['q_ids'];
    final qIds = <String>[];
    if (qRaw is List) {
      for (final e in qRaw) {
        if (e != null) {
          qIds.add(e.toString());
        }
      }
    }

    final gc = data['generated_count'];
    final generatedCount = gc is int ?
        gc :
        gc is num ?
            gc.toInt() :
            0;

    final slotKey = data['slot_key'] as String? ?? '';
    final mode = data['mode'] as String? ?? 'classic';

    return Tournament(
      slotId: sid,
      slotKey: slotKey.isNotEmpty ? slotKey : _inferSlotKey(sid),
      mode: mode,
      status: st,
      categoryId: cat,
      startsAt: startsRaw.toDate(),
      endsAt: endsRaw.toDate(),
      generatedCount: generatedCount,
      qIds: qIds,
    );
  }

  static String _inferSlotKey(String slotId) {
    if (slotId.endsWith('_07utc')) {
      return '07utc';
    }
    if (slotId.endsWith('_23utc')) {
      return '23utc';
    }
    return '';
  }
}
