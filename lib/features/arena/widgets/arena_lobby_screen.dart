import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/countdown_ticker.dart';
import '../../../core/widgets/mascot_empty_state.dart';
import '../data/arena_models.dart';
import '../data/arena_service.dart';

class ArenaLobbyScreen extends StatefulWidget {
  const ArenaLobbyScreen({super.key});

  @override
  State<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends State<ArenaLobbyScreen> {
  final ArenaService _arenaService = ArenaService();
  StreamSubscription<ArenaDoc?>? _sub;
  ArenaDoc? _arena;
  bool _streamReady = false;
  String? _boundArenaId;

  ArenaDoc? _previous;
  bool _pushedQuiz = false;
  bool _pushedResult = false;

  void _ensureSub(String arenaId) {
    if (_boundArenaId == arenaId) {
      return;
    }
    _boundArenaId = arenaId;
    _sub?.cancel();
    _previous = null;
    _pushedQuiz = false;
    _pushedResult = false;
    _sub = _arenaService.watchArena(arenaId).listen((doc) {
      if (doc != null) {
        _handleArenaUpdate(doc);
      }
      if (mounted) {
        setState(() {
          _arena = doc;
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

  void _handleArenaUpdate(ArenaDoc arena) {
    final prev = _previous;
    _previous = arena;

    if (!mounted) {
      return;
    }

    if (prev == null) {
      if (arena.status == 'running') {
        _pushQuizOnce(arena.id);
      } else if (arena.isTerminal) {
        _pushResultOnce(arena.id);
      }
      return;
    }

    if ((prev.status == 'scheduled' || prev.status == 'preparing') &&
        arena.status == 'running') {
      _pushQuizOnce(arena.id);
    }
    if (prev.status != 'ended' && arena.status == 'ended') {
      _pushResultOnce(arena.id);
    }
    if (prev.status != 'no_participants' && arena.status == 'no_participants') {
      _pushResultOnce(arena.id);
    }
    if (prev.status != 'generation_failed' &&
        arena.status == 'generation_failed') {
      _pushResultOnce(arena.id);
    }
  }

  void _pushQuizOnce(String arenaId) {
    if (_pushedQuiz || _pushedResult) {
      return;
    }
    _pushedQuiz = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.pushNamed(
        'arena-quiz',
        queryParameters: {'arenaId': arenaId},
      );
    });
  }

  void _pushResultOnce(String arenaId) {
    if (_pushedResult) {
      return;
    }
    _pushedResult = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.pushNamed(
        'arena-result',
        queryParameters: {'arenaId': arenaId},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final arenaId =
        GoRouterState.of(context).uri.queryParameters['arenaId']?.trim();

    if (arenaId == null || arenaId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_lobby_title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.arena_invite_missing_params),
        ),
      );
    }

    _ensureSub(arenaId);

    final arena = _arena;
    if (!_streamReady && arena == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_lobby_title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (arena == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.arena_lobby_title)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.arena_join_error_not_found),
        ),
      );
    }

    return StreamBuilder<List<ArenaParticipant>>(
      stream: _arenaService.listenToParticipants(arena.id),
      builder: (context, partSnap) {
        final participants = partSnap.data ?? [];

        final uid = FirebaseAuth.instance.currentUser?.uid;
        final isCreator = uid != null && uid == arena.creatorId;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.arena_lobby_title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                arena.name?.trim().isNotEmpty == true
                    ? arena.name!.trim()
                    : l10n.arena_lobby_untitled,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(
                      arena.mode == 'battle'
                          ? l10n.arena_create_mode_battle
                          : l10n.arena_create_mode_list,
                    ),
                  ),
                  if (arena.sourceType == 'preset' && arena.categoryId != null)
                    Chip(label: Text(_categoryLabel(l10n, arena.categoryId!))),
                  if (arena.sourceType == 'custom_topic' &&
                      arena.customTopic != null)
                    Chip(label: Text(arena.customTopic!)),
                ],
              ),
              const SizedBox(height: 16),
              CountdownTicker(
                targetUtc: arena.scheduledStartAt.toUtc(),
                format: (r) => l10n.arena_lobby_starting_in(
                  CountdownTicker.formatHoursMinutes(r),
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.arena_lobby_participants(participants.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (participants.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: MascotEmptyState(
                    title: l10n.arena_lobby_participants(0),
                    body: l10n.arena_lobby_solo_hint,
                  ),
                )
              else ...[
                if (participants.length == 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.arena_lobby_solo_hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ...participants.map((_) {
                  return ListTile(
                    title: Text(l10n.arena_lobby_anonymous_player),
                  );
                }),
              ],
              if (isCreator) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.arena_lobby_invite_code_label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        'BJ-${arena.inviteCode.toUpperCase()}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.arena_lobby_copy,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: arena.inviteCode.toUpperCase()),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.arena_lobby_copy)),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: l10n.arena_invite_share_action,
                      onPressed: () async {
                        final text =
                            l10n.arena_invite_share_message(arena.inviteCode);
                        await Share.share(text);
                      },
                      icon: const Icon(Icons.share),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go('/arena'),
                child: Text(l10n.arena_lobby_leave),
              ),
            ],
          ),
        );
      },
    );
  }

  String _categoryLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'history':
        return l10n.arena_category_history;
      case 'geography':
        return l10n.arena_category_geography;
      case 'movies_tv':
        return l10n.arena_category_movies_tv;
      case 'music':
        return l10n.arena_category_music;
      case 'sports':
        return l10n.arena_category_sports;
      case 'science':
        return l10n.arena_category_science;
      case 'technology':
        return l10n.arena_category_technology;
      case 'literature':
        return l10n.arena_category_literature;
      case 'art':
        return l10n.arena_category_art;
      case 'food_drink':
        return l10n.arena_category_food_drink;
      case 'animals':
        return l10n.arena_category_animals;
      case 'nature':
        return l10n.arena_category_nature;
      case 'pop_culture':
        return l10n.arena_category_pop_culture;
      case 'mythology':
        return l10n.arena_category_mythology;
      case 'video_games':
        return l10n.arena_category_video_games;
      case 'fashion':
        return l10n.arena_category_fashion;
      case 'astrology':
        return l10n.arena_category_astrology;
      case 'health':
        return l10n.arena_category_health;
      case 'space':
        return l10n.arena_category_space;
      case 'world_capitals':
        return l10n.arena_category_world_capitals;
      default:
        return id;
    }
  }
}
