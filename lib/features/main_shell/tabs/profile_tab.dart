import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../achievements/achievement_definition.dart';

/// Profile tab — XP / Level / Streak from `users/{uid}` (same body for all users).
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _nudgeDismissedLocally = false;
  bool _forceRenameFlowActive = false;

  static Stream<DocumentSnapshot<Map<String, dynamic>>?> _userDocStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  static int _intField(Map<String, dynamic>? data, String key) {
    if (data == null) {
      return 0;
    }
    final raw = data[key];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return 0;
  }

  static bool _isNudgeHiddenUntilActive(Map<String, dynamic>? data) {
    final raw = data?['profileNudgeHiddenUntil'];
    if (raw is Timestamp) {
      return raw.toDate().isAfter(DateTime.now());
    }
    return false;
  }

  static Future<Set<String>> _fetchEarnedAchievementIds(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('achievements')
        .doc(uid)
        .collection('earned')
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }

  static bool _displayNameMissing(Map<String, dynamic>? data) {
    final name = data?['displayName'];
    if (name == null) {
      return true;
    }
    if (name is String && name.trim().isEmpty) {
      return true;
    }
    return false;
  }

  Future<void> _runForceRenameLoop() async {
    if (_forceRenameFlowActive || !mounted) {
      return;
    }
    _forceRenameFlowActive = true;
    try {
      while (mounted) {
        final result = await context.pushNamed<bool>('username-creation');
        if (result == true) {
          break;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _forceRenameFlowActive = false);
      } else {
        _forceRenameFlowActive = false;
      }
    }
  }

  Future<void> _snoozeAnonymousNudge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    setState(() => _nudgeDismissedLocally = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'profileNudgeHiddenUntil': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Card already hidden locally; stream will reconcile on next snapshot.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final isAnonymous = user?.isAnonymous == true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTabProfile)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        stream: _userDocStream(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final xp = _intField(data, 'xp');
          final level = _intField(data, 'level');
          final streak = _intField(data, 'streak');

          final showAnonymousNudge = isAnonymous &&
              !_nudgeDismissedLocally &&
              !_isNudgeHiddenUntilActive(data);

          final forceRename = data?['forceRename'] == true;
          if (forceRename && !_forceRenameFlowActive) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _forceRenameFlowActive) {
                return;
              }
              _runForceRenameLoop();
            });
          }

          final showUsernameNudge = !isAnonymous &&
              _displayNameMissing(data) &&
              !forceRename;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showAnonymousNudge) ...[
                    _AnonymousNudgeCard(
                      theme: theme,
                      onSaveAccount: () =>
                          context.pushNamed('onboarding-sign-in'),
                      onMaybeLater: _snoozeAnonymousNudge,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'XP',
                          value: xp,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Level',
                          value: level,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Streak',
                          value: streak,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  if (showUsernameNudge) ...[
                    const SizedBox(height: 16),
                    _UsernameNudgeCard(
                      theme: theme,
                      onChooseUsername: () =>
                          context.pushNamed('username-creation'),
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushNamed('settings'),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<Set<String>>(
                    key: ValueKey<String?>(uid),
                    future: uid != null ?
                        _fetchEarnedAchievementIds(uid) :
                        Future<Set<String>>.value(<String>{}),
                    builder: (context, earnedSnapshot) {
                      final earnedIds = earnedSnapshot.data ?? <String>{};
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Achievements',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: BrainjaminAchievement.values.length,
                            itemBuilder: (context, index) {
                              final achievement =
                                  BrainjaminAchievement.values[index];
                              final earned =
                                  earnedIds.contains(achievement.id);
                              return _AchievementCell(
                                achievement: achievement,
                                earned: earned,
                                theme: theme,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UsernameNudgeCard extends StatelessWidget {
  const _UsernameNudgeCard({
    required this.theme,
    required this.onChooseUsername,
  });

  final ThemeData theme;
  final VoidCallback onChooseUsername;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrainjaminColors.brandOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: BrainjaminColors.brandOrange,
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set your username',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: BrainjaminColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a username to appear on leaderboards and in games.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onChooseUsername,
              child: const Text('Choose username'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnonymousNudgeCard extends StatelessWidget {
  const _AnonymousNudgeCard({
    required this.theme,
    required this.onSaveAccount,
    required this.onMaybeLater,
  });

  final ThemeData theme;
  final VoidCallback onSaveAccount;
  final VoidCallback onMaybeLater;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrainjaminColors.brandOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: BrainjaminColors.brandOrange,
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your progress is at risk',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: BrainjaminColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Streak ✓ · XP ✓ · Leaderboards ✗ — save your account to unlock everything.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BrainjaminColors.onSurfaceMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSaveAccount,
              child: const Text('Save my account'),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onMaybeLater,
            child: const Text('Maybe later'),
          ),
        ],
      ),
    );
  }
}

class _AchievementCell extends StatelessWidget {
  const _AchievementCell({
    required this.achievement,
    required this.earned,
    required this.theme,
  });

  final BrainjaminAchievement achievement;
  final bool earned;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: earned ?
              BrainjaminColors.brandOrange.withValues(alpha: 0.12) :
              Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              achievement.iconData,
              size: 28,
              color: earned ?
                  BrainjaminColors.brandOrange :
                  Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: earned ?
                    BrainjaminColors.onSurface :
                    BrainjaminColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final int value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: BrainjaminColors.brandOrange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: BrainjaminColors.brandOrangeDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: BrainjaminColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
