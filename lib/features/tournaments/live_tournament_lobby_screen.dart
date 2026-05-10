import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/server_time_service.dart';
import '../../core/widgets/countdown_ticker.dart';
import 'data/live_tournament.dart';
import 'services/live_tournament_service.dart';

/// Lobby listens only to `live_tournaments/{ltId}` (single-doc fan-out).
class LiveTournamentLobbyScreen extends StatefulWidget {
  const LiveTournamentLobbyScreen({
    super.key,
    required this.ltId,
  });

  final String ltId;

  @override
  State<LiveTournamentLobbyScreen> createState() =>
      _LiveTournamentLobbyScreenState();
}

class _LiveTournamentLobbyScreenState extends State<LiveTournamentLobbyScreen> {
  late final LiveTournamentService _service;
  StreamSubscription<LiveTournament?>? _sub;
  LiveTournament? _live;
  bool _streamReady = false;

  LiveTournament? _previous;
  bool _pushedQuiz = false;
  bool _pushedResult = false;
  bool _joined = false;
  bool _joinBusy = false;

  @override
  void initState() {
    super.initState();
    _service = LiveTournamentService();
    _sub = _service.watchOne(widget.ltId).listen((live) {
      if (live != null) {
        _handleLiveUpdate(live);
      }
      if (mounted) {
        setState(() {
          _live = live;
          _streamReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleLiveUpdate(LiveTournament live) {
    final prev = _previous;
    _previous = live;

    if (!mounted) {
      return;
    }

    if (prev == null) {
      if (live.status == 'ended') {
        _pushResultOnce();
      }
      return;
    }

    if (prev.status == 'scheduled' && live.status == 'running') {
      _pushQuizOnce();
    }
    if (prev.status != 'ended' && live.status == 'ended') {
      _pushResultOnce();
    }
  }

  void _pushQuizOnce() {
    if (_pushedQuiz || _pushedResult) {
      return;
    }
    _pushedQuiz = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.pushNamed(
        'live-tournament-quiz',
        pathParameters: {'ltId': widget.ltId},
      );
    });
  }

  void _pushResultOnce() {
    if (_pushedResult) {
      return;
    }
    _pushedResult = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.pushNamed(
        'live-tournament-result',
        pathParameters: {'ltId': widget.ltId},
      );
    });
  }

  String _statusCopy(LiveTournament t) {
    final now = ServerTimeService.now();
    switch (t.status) {
      case 'scheduled':
        if (t.startsAt.isAfter(now)) {
          return "Brainjamin's lining up the questions — pull up a chair";
        }
        return "Brainjamin's lining up the questions — pull up a chair";
      case 'running':
        if (t.lateJoinClosed) {
          return "Late join closed. Catch the next one in a few hours.";
        }
        return "Tournament's already started — jump in if you can keep up";
      case 'ended':
        return "This one wrapped up. Next round's coming.";
      case 'no_participants':
        return "Empty house. Brainjamin's preparing the next slot.";
      case 'no_pool_questions':
      case 'generation_failed':
        return "Couldn't get this one off the ground. Try the next slot.";
      default:
        return 'Checking the lobby…';
    }
  }

  bool _isTerminal(LiveTournament t) => t.isTerminal;

  bool _showJoin(LiveTournament t) {
    if (_isTerminal(t)) {
      return false;
    }
    if (t.isRunning && t.lateJoinClosed) {
      return false;
    }
    return t.isScheduled || t.isRunning;
  }

  Future<void> _onJoin() async {
    setState(() => _joinBusy = true);
    try {
      await _service.join(widget.ltId);
      if (!mounted) {
        return;
      }
      setState(() {
        _joined = true;
        _joinBusy = false;
      });
    } on LiveJoinException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _joinBusy = false);
      final msg = switch (e.reason) {
        LiveJoinReason.lateJoinClosed =>
          'Late join just closed — sorry, missed the window.',
        LiveJoinReason.tournamentEnded => 'This tournament just ended.',
        LiveJoinReason.unknown =>
          "Couldn't join right now. Try again?",
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _joinBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't join right now. Try again?"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tournament'),
      ),
      body: !_streamReady ?
          const Center(child: CircularProgressIndicator()) :
          _live == null ?
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'This live tournament could not be loaded.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ) :
          _buildBody(context, theme, _live!),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    LiveTournament live,
  ) {
    final now = ServerTimeService.now();
    final showCountdownHero =
        live.status == 'scheduled' && live.startsAt.isAfter(now);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          showCountdownHero ?
              'Starts in' :
              (live.isRunning ? 'Status' : 'Starting'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: BrainjaminColors.onSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Center(
          child: showCountdownHero ?
              CountdownTicker(
                targetUtc: live.startsAt,
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: BrainjaminColors.brandOrange,
                ),
                format: CountdownTicker.formatHoursMinutes,
                onZeroBuilder: (ctx) => Text(
                  "We're live",
                  style: theme.textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BrainjaminColors.brandOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ) :
              Text(
                live.isRunning ?
                    "We're live" :
                    'Starting soon',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: BrainjaminColors.brandOrange,
                ),
                textAlign: TextAlign.center,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          _statusCopy(live),
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'Players in the lobby: ${live.totalParticipants}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_showJoin(live)) ...[
          FilledButton(
            onPressed: (_joinBusy || _joined) ? null : () => _onJoin(),
            child: _joinBusy ?
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) :
                Text(
                  _joined ?
                      "You're in. Hold tight." :
                      'Join',
                ),
          ),
        ],
      ],
    );
  }
}
