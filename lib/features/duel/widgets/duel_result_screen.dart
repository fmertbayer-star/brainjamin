import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/duel_service.dart';
import '../../../core/utils/safe_stream_cancel.dart';

class DuelResultScreen extends StatefulWidget {
  const DuelResultScreen({super.key});

  @override
  State<DuelResultScreen> createState() => _DuelResultScreenState();
}

class _DuelResultScreenState extends State<DuelResultScreen> {
  final DuelService _duelService = DuelService();

  String? _duelId;
  bool _badParams = false;
  DocumentSnapshot<Map<String, dynamic>>? _latestSnap;
  Object? _streamError;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  String? _metaCacheRouteDuelId;
  List<DuelQuestionMetadataRow>? _duelQuestionMeta;
  bool _duelQuestionMetaInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeDuelId = GoRouterState.of(context).uri.queryParameters['duelId']?.trim();
    if (routeDuelId != null &&
        routeDuelId.isNotEmpty &&
        routeDuelId != _metaCacheRouteDuelId) {
      _metaCacheRouteDuelId = routeDuelId;
      _duelQuestionMeta = null;
      _duelQuestionMetaInFlight = false;
    }
    if (_badParams || _subscription != null) return;

    final id = GoRouterState.of(context).uri.queryParameters['duelId']?.trim();
    if (id == null || id.isEmpty) {
      setState(() {
        _badParams = true;
      });
      return;
    }
    _duelId = id;

    _subscription = _duelService.listenToDuel(id).listen(
      (snap) {
        if (mounted) {
          setState(() {
            _latestSnap = snap;
            _streamError = null;
          });
        }
      },
      onError: (Object err) {
        debugPrint('[duel-result-stream-error] duelId=$_duelId error=$err');
        if (mounted) {
          setState(() {
            _streamError = err;
            _latestSnap = null;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    safeCancelSubscription(_subscription);
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return null;
  }

  String _formatDurationMs(int ms) {
    final secs = (ms / 1000).round();
    if (secs < 60) {
      return '${secs}s';
    }
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}m ${s}s';
  }

  void _requestDuelQuestionMetaOnce() {
    final id = _duelId;
    if (id == null || id.isEmpty) return;
    if (_duelQuestionMeta != null) return;
    if (_duelQuestionMetaInFlight) return;
    _duelQuestionMetaInFlight = true;
    _duelService.fetchDuelQuestionsMetadata(id).then((rows) {
      if (!mounted || _duelId != id) {
        if (mounted) {
          setState(() => _duelQuestionMetaInFlight = false);
        }
        return;
      }
      setState(() {
        _duelQuestionMeta = rows;
        _duelQuestionMetaInFlight = false;
      });
    }).catchError((Object _) {
      if (!mounted || _duelId != id) {
        if (mounted) {
          setState(() => _duelQuestionMetaInFlight = false);
        }
        return;
      }
      setState(() {
        _duelQuestionMeta = [];
        _duelQuestionMetaInFlight = false;
      });
    });
  }

  String? _categoryDifficultySummaryLine(
    AppLocalizations l10n,
    List<DuelQuestionMetadataRow> rows,
  ) {
    if (rows.isEmpty) return null;
    final cats = <String>{};
    final difficulties = <int>[];
    for (final r in rows) {
      final c = r.category?.trim();
      if (c != null && c.isNotEmpty) {
        cats.add(c);
      }
      if (r.difficulty != null) {
        difficulties.add(r.difficulty!);
      }
    }
    if (cats.isEmpty || difficulties.isEmpty) return null;
    final minD = difficulties.reduce(math.min);
    final maxD = difficulties.reduce(math.max);
    final n = cats.length;
    if (n == 1) {
      return l10n.duelResultStatSummaryOneCategory(minD, maxD);
    }
    return l10n.duelResultStatSummary(n, minD, maxD);
  }

  Widget _statComparisonRow(
    ThemeData theme,
    String label,
    String left,
    String right, {
    required bool leftHighlight,
    required bool rightHighlight,
  }) {
    Widget valueCell(String text, bool highlight) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (highlight)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                excludeSemantics: true,
                child: const Icon(
                  Icons.bolt,
                  size: 16,
                ),
              ),
            ),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.titleSmall),
          ),
          Expanded(
            child: valueCell(left, leftHighlight),
          ),
          Expanded(
            child: valueCell(right, rightHighlight),
          ),
        ],
      ),
    );
  }

  bool _hasSubmitted(Map<String, dynamic> d, String? uid) {
    if (uid == null || uid.isEmpty) return false;
    final p1 = d['player1_id'];
    final p2 = d['player2_id'];
    if (p1 == uid) return d['player1_done_at'] != null;
    if (p2 == uid) return d['player2_done_at'] != null;
    return false;
  }

  Widget _notReady(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.duelResultNotReady),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(l10n.duelResultBackHome),
          ),
        ],
      ),
    );
  }

  Widget _footerActions(AppLocalizations l10n, {VoidCallback? onNewDuel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onNewDuel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              onPressed: onNewDuel,
              child: Text(l10n.duelResultNewDuel),
            ),
          ),
        TextButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.duelResultBackHome),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.duelResultTitle)),
        body: Builder(
          builder: (context) {
            if (_badParams || _duelId == null) {
              return _notReady(l10n);
            }

            if (_streamError != null) {
              return _notReady(l10n);
            }

            if (_latestSnap == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!_latestSnap!.exists || _latestSnap!.data() == null) {
              return _notReady(l10n);
            }

            final Map<String, dynamic> data =
                Map<String, dynamic>.from(_latestSnap!.data()!);

            final status = data['status'] is String ? data['status'] as String : '';
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final p1Id =
                data['player1_id'] is String ? data['player1_id'] as String : '';
            final p2Raw = data['player2_id'];
            final p2Str = p2Raw is String && p2Raw.isNotEmpty ? p2Raw : null;

            final isP1 = uid != null && uid == p1Id;
            final isP2 = uid != null && p2Str != null && uid == p2Str;
            final p1Done = data['player1_done_at'] != null;
            final p2Done = data['player2_done_at'] != null;

            if (status == 'expired') {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.duelResultNotReady),
                    const Spacer(),
                    _footerActions(l10n),
                  ],
                ),
              );
            }

            // --- Completed duel ---
            if (status == 'completed') {
              final p1Correct = _asInt(data['player1_correct_count']) ?? 0;
              final p2Correct = _asInt(data['player2_correct_count']) ?? 0;
              final myCorrect = isP1 ? p1Correct : (isP2 ? p2Correct : p1Correct);
              final theirCorrect = isP1 ? p2Correct : (isP2 ? p1Correct : p2Correct);

              final winnerId = data['winner_id'];

              late final String outcome;
              late final IconData badgeIcon;
              late final Color badgeAccent;
              if (winnerId == null) {
                outcome = l10n.duelResultTie;
                badgeIcon = Icons.balance;
                badgeAccent = Theme.of(context).colorScheme.tertiary;
              } else if (uid != null && winnerId == uid) {
                outcome = l10n.duelResultYouWon;
                badgeIcon = Icons.emoji_events_outlined;
                badgeAccent = Theme.of(context).colorScheme.primary;
              } else if (uid != null && winnerId != uid) {
                outcome = l10n.duelResultYouLost;
                badgeIcon = Icons.sports_esports_outlined;
                badgeAccent = Theme.of(context).colorScheme.outline;
              } else {
                outcome = l10n.duelResultTie;
                badgeIcon = Icons.balance;
                badgeAccent = Theme.of(context).colorScheme.tertiary;
              }

              final p1TimeMs = _asInt(data['player1_time_ms']) ?? 0;
              final p2TimeMs = _asInt(data['player2_time_ms']) ?? 0;
              final myTimeMs =
                  isP1 ? p1TimeMs : (isP2 ? p2TimeMs : p1TimeMs);
              final theirTimeMs =
                  isP1 ? p2TimeMs : (isP2 ? p1TimeMs : p2TimeMs);
              int? fasterSide;
              if (p1TimeMs < p2TimeMs) {
                fasterSide = 1;
              } else if (p2TimeMs < p1TimeMs) {
                fasterSide = 2;
              }
              final myTimeFaster =
                  (isP1 && fasterSide == 1) || (isP2 && fasterSide == 2);
              final theirTimeFaster =
                  (isP1 && fasterSide == 2) || (isP2 && fasterSide == 1);

              final p1Score = _asDouble(data['player1_score']) ?? 0.0;
              final p2Score = _asDouble(data['player2_score']) ?? 0.0;
              final myScore =
                  isP1 ? p1Score : (isP2 ? p2Score : p1Score);
              final theirScore =
                  isP1 ? p2Score : (isP2 ? p1Score : p2Score);

              String timeWithFaster(int ms, bool faster) {
                final base = _formatDurationMs(ms);
                return faster ? '$base${l10n.duelResultStatFaster}' : base;
              }

              final theme = Theme.of(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _requestDuelQuestionMetaOnce();
              });

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: badgeAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: badgeAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, color: badgeAccent, size: 28),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                outcome,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: badgeAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.duelResultMyCorrect(myCorrect)),
                    Text(l10n.duelResultTheirCorrect(theirCorrect)),
                    const SizedBox(height: 16),
                    Text(l10n.duelResultXpEarned),
                    const SizedBox(height: 16),
                    Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _statComparisonRow(
                              theme,
                              l10n.duelResultStatAccuracy,
                              '$myCorrect/10',
                              '$theirCorrect/10',
                              leftHighlight: false,
                              rightHighlight: false,
                            ),
                            _statComparisonRow(
                              theme,
                              l10n.duelResultStatTotalTime,
                              timeWithFaster(myTimeMs, myTimeFaster),
                              timeWithFaster(theirTimeMs, theirTimeFaster),
                              leftHighlight: myTimeFaster,
                              rightHighlight: theirTimeFaster,
                            ),
                            _statComparisonRow(
                              theme,
                              l10n.duelResultStatScore,
                              myScore.toStringAsFixed(1),
                              theirScore.toStringAsFixed(1),
                              leftHighlight: false,
                              rightHighlight: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_duelQuestionMeta != null &&
                        _duelQuestionMeta!.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final line = _categoryDifficultySummaryLine(
                            l10n,
                            _duelQuestionMeta!,
                          );
                          if (line == null) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    _footerActions(
                      l10n,
                      onNewDuel: () => context.go('/duel/match-type'),
                    ),
                  ],
                ),
              );
            }

            final submitted = _hasSubmitted(data, uid);

            if (uid == null || !(isP1 || isP2)) {
              return _notReady(l10n);
            }

            if (!submitted) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.duelResultNotReady),
                    const Spacer(),
                    _footerActions(l10n),
                  ],
                ),
              );
            }

            // --- Creator still unmatched (solo round done); random queue ---
            final seekOpponentQueue = status == 'waiting' && isP1 && p1Done;
            final seekAfterSoloSubmit =
                status == 'player1_done' && isP1 && p1Done && p2Str == null;
            if (seekOpponentQueue || seekAfterSoloSubmit) {
              final mc = _asInt(data['player1_correct_count']) ?? 0;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.duelResultSeekMatch),
                    const SizedBox(height: 12),
                    Text(l10n.duelResultMyCorrect(mc)),
                    const Spacer(),
                    _footerActions(l10n),
                  ],
                ),
              );
            }

            // --- Finished locally; challenger still owes answers ---
            final awaitRival = (isP1 && p1Done && p2Str != null && !p2Done) ||
                (isP2 && p2Done && !p1Done);

            if (awaitRival) {
              final mc = isP1 ?
                  (_asInt(data['player1_correct_count']) ?? 0) :
                  (_asInt(data['player2_correct_count']) ?? 0);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.duelResultAwaitRivalAnswers),
                    const SizedBox(height: 12),
                    Text(l10n.duelResultMyCorrect(mc)),
                    const Spacer(),
                    _footerActions(l10n),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.duelResultNotReady),
                  const Spacer(),
                  _footerActions(l10n),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
