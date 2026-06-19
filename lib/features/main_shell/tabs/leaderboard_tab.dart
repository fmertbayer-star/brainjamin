import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/mascot_empty_state.dart';

/// ISO week key in UTC (`YYYY-Www`), matching Cloud Functions luxon format.
String utcIsoWeekKey() {
  final date = DateTime.now().toUtc();
  final weekday = date.weekday;
  final thursday = date.add(Duration(days: 4 - weekday));
  final isoYear = thursday.year;
  final jan4 = DateTime.utc(isoYear, 1, 4);
  final week1Thursday = jan4.add(Duration(days: 4 - jan4.weekday));
  final week =
      ((thursday.difference(week1Thursday).inDays) / 7).floor() + 1;
  return '$isoYear-W${week.toString().padLeft(2, '0')}';
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.xp,
    required this.level,
  });

  final int rank;
  final String uid;
  final String displayName;
  final int xp;
  final int level;
}

class _LeaderboardData {
  const _LeaderboardData({
    required this.globalEntries,
    required this.weeklyEntries,
  });

  final List<LeaderboardEntry> globalEntries;
  final List<LeaderboardEntry> weeklyEntries;
}

List<LeaderboardEntry> _parseEntries(DocumentSnapshot<Map<String, dynamic>> snap) {
  if (!snap.exists) {
    return [];
  }
  final raw = snap.data()?['entries'];
  if (raw is! List) {
    return [];
  }
  final entries = <LeaderboardEntry>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final rank = map['rank'];
    final uid = map['uid'];
    if (rank is! num || uid is! String) {
      continue;
    }
    final displayName = map['displayName'];
    final xp = map['xp'];
    final level = map['level'];
    entries.add(
      LeaderboardEntry(
        rank: rank.toInt(),
        uid: uid,
        displayName: displayName is String ? displayName : '',
        xp: xp is num ? xp.toInt() : 0,
        level: level is num ? level.toInt() : 0,
      ),
    );
  }
  entries.sort((a, b) => a.rank.compareTo(b.rank));
  return entries;
}

Future<_LeaderboardData> _fetchLeaderboards() async {
  final weekKey = utcIsoWeekKey();
  final db = FirebaseFirestore.instance;
  final results = await Future.wait([
    db.collection('leaderboards').doc('global').get(),
    db.collection('leaderboards').doc('weekly_$weekKey').get(),
  ]);
  return _LeaderboardData(
    globalEntries: _parseEntries(results[0]),
    weeklyEntries: _parseEntries(results[1]),
  );
}

/// Leaderboard tab — anonymous gate; permanent users see global + weekly rankings.
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  late final Future<_LeaderboardData> _leaderboardsFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardsFuture = _fetchLeaderboards();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return StreamBuilder<User?>(
        stream: BrainjaminAuthService.authStateChanges,
        initialData: BrainjaminAuthService.currentUser,
        builder: (context, snapshot) {
          final isAnonymous = snapshot.data?.isAnonymous == true;

          if (isAnonymous) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.mainTabLeaderboard)),
              body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Leaderboards are for registered players',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BrainjaminColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a free account to see where you rank globally.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: BrainjaminColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            context.pushNamed('onboarding-sign-in'),
                        child: const Text('Save my account'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Maybe later'),
                    ),
                  ],
                ),
              ),
            ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: Text(l10n.mainTabLeaderboard),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Global'),
                    Tab(text: 'This Week'),
                  ],
                ),
              ),
              body: FutureBuilder<_LeaderboardData>(
                    future: _leaderboardsFuture,
                    builder: (context, lbSnapshot) {
                      if (lbSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (lbSnapshot.hasError) {
                        return const MascotEmptyState(
                          title: 'No rankings yet',
                          body:
                              'Check back soon — rankings update hourly.',
                        );
                      }
                      final data = lbSnapshot.data;
                      if (data == null) {
                        return const MascotEmptyState(
                          title: 'No rankings yet',
                          body:
                              'Check back soon — rankings update hourly.',
                        );
                      }

                      return TabBarView(
                        children: [
                          _LeaderboardList(entries: data.globalEntries),
                          _LeaderboardList(entries: data.weeklyEntries),
                        ],
                      );
                    },
                  ),
            ),
          );
        },
      );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.entries});

  final List<LeaderboardEntry> entries;

  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  Color _rankColor(int rank, ThemeData theme) {
    return switch (rank) {
      1 => _gold,
      2 => _silver,
      3 => _bronze,
      _ => BrainjaminColors.onSurfaceMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const MascotEmptyState(
        title: 'No rankings yet',
        body: 'Check back soon — rankings update hourly.',
      );
    }

    final theme = Theme.of(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isCurrentUser =
            currentUid != null && entry.uid == currentUid;
        final rankColor = _rankColor(entry.rank, theme);

        return ColoredBox(
          color: isCurrentUser ?
              BrainjaminColors.brandOrange.withValues(alpha: 0.08) :
              Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${entry.rank}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: rankColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.displayName.isNotEmpty ?
                        entry.displayName :
                        'Anonymous Player',
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.xp} XP',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: BrainjaminColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
