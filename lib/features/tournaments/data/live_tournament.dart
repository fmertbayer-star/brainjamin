import 'package:cloud_firestore/cloud_firestore.dart';

import 'live_top100_entry.dart';

/// Single-doc fan-out row from `live_tournaments/{ltId}`.
class LiveTournament {
  const LiveTournament({
    required this.slotId,
    required this.slotKey,
    required this.mode,
    required this.status,
    required this.startsAt,
    required this.currentQuestion,
    required this.revealActive,
    required this.lateJoinClosed,
    required this.totalParticipants,
    required this.finalizedAt,
    required this.endedAt,
    this.top100 = const [],
    this.totalFinalizedParticipants,
  });

  final String slotId;
  final String slotKey;
  final String mode;
  final String status;
  final DateTime startsAt;
  final int? currentQuestion;
  final bool revealActive;
  final bool lateJoinClosed;
  final int totalParticipants;
  final DateTime? finalizedAt;
  final DateTime? endedAt;
  final List<LiveTop100Entry> top100;
  final int? totalFinalizedParticipants;

  bool get isScheduled => status == 'scheduled';
  bool get isRunning => status == 'running';
  bool get isEnded => status == 'ended';

  bool get isTerminal =>
      status == 'ended' ||
      status == 'no_participants' ||
      status == 'no_pool_questions' ||
      status == 'generation_failed';

  factory LiveTournament.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw ArgumentError.value(doc.id, 'doc', 'missing live tournament data');
    }
    final sid = data['slot_id'] as String? ?? doc.id;
    final sk = data['slot_key'] as String? ?? '';
    final st = data['status'] as String?;
    if (st == null || st.isEmpty) {
      throw ArgumentError('missing status on live tournament ${doc.id}');
    }

    final startsRaw = data['starts_at'];
    if (startsRaw is! Timestamp) {
      throw ArgumentError('missing starts_at on live tournament ${doc.id}');
    }

    final cqRaw = data['current_question'];
    int? currentQuestion;
    if (cqRaw == null) {
      currentQuestion = null;
    } else if (cqRaw is int) {
      currentQuestion = cqRaw;
    } else if (cqRaw is num) {
      currentQuestion = cqRaw.toInt();
    }

    final finalizedRaw = data['finalized_at'];
    final endedRaw = data['ended_at'];

    final topRaw = data['top_100'];
    final top100 = <LiveTop100Entry>[];
    if (topRaw is List) {
      for (final e in topRaw) {
        if (e is Map<String, dynamic>) {
          try {
            top100.add(LiveTop100Entry.fromMap(e));
          } on Object catch (_) {}
        } else if (e is Map) {
          try {
            top100.add(
              LiveTop100Entry.fromMap(Map<String, dynamic>.from(e)),
            );
          } on Object catch (_) {}
        }
      }
    }

    final tfpRaw = data['total_finalized_participants'];
    final int? totalFinalizedParticipants;
    if (tfpRaw == null) {
      totalFinalizedParticipants = null;
    } else if (tfpRaw is int) {
      totalFinalizedParticipants = tfpRaw;
    } else if (tfpRaw is num) {
      totalFinalizedParticipants = tfpRaw.toInt();
    } else {
      totalFinalizedParticipants = null;
    }

    return LiveTournament(
      slotId: sid,
      slotKey: sk.isNotEmpty ? sk : _inferSlotKey(sid),
      mode: data['mode'] as String? ?? 'live',
      status: st,
      startsAt: startsRaw.toDate(),
      currentQuestion: currentQuestion,
      revealActive: data['reveal_active'] == true,
      lateJoinClosed: data['late_join_closed'] == true,
      totalParticipants: _readInt(data['total_participants']),
      finalizedAt: finalizedRaw is Timestamp ? finalizedRaw.toDate() : null,
      endedAt: endedRaw is Timestamp ? endedRaw.toDate() : null,
      top100: top100,
      totalFinalizedParticipants: totalFinalizedParticipants,
    );
  }

  static int _readInt(dynamic v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return 0;
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
