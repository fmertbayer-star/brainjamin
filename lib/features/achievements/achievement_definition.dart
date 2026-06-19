import 'package:flutter/material.dart';

/// Launch achievement catalog (V1). Pure metadata — unlock state lives in Firestore.
enum BrainjaminAchievement {
  streak3(
    id: 'streak_3',
    title: 'On a Roll',
    description: '3-day streak',
    iconData: Icons.local_fire_department,
  ),
  streak7(
    id: 'streak_7',
    title: 'Week Warrior',
    description: '7-day streak',
    iconData: Icons.local_fire_department,
  ),
  streak30(
    id: 'streak_30',
    title: 'Monthly Master',
    description: '30-day streak',
    iconData: Icons.local_fire_department,
  ),
  streak100(
    id: 'streak_100',
    title: 'Century Flame',
    description: '100-day streak',
    iconData: Icons.local_fire_department,
  ),
  firstQuestion(
    id: 'first_question',
    title: 'First Step',
    description: 'Answer your first question',
    iconData: Icons.star,
  ),
  questions100(
    id: 'questions_100',
    title: 'Century Club',
    description: 'Answer 100 questions',
    iconData: Icons.star,
  ),
  questions1000(
    id: 'questions_1000',
    title: 'Trivia Veteran',
    description: 'Answer 1,000 questions',
    iconData: Icons.star,
  ),
  questions10000(
    id: 'questions_10000',
    title: 'Brainjamin Legend',
    description: 'Answer 10,000 questions',
    iconData: Icons.star,
  ),
  tournamentFirst(
    id: 'tournament_first',
    title: 'Tournament Debut',
    description: 'Join your first tournament',
    iconData: Icons.emoji_events,
  ),
  tournamentTop10(
    id: 'tournament_top10',
    title: 'Top 10',
    description: 'Finish in the top 10',
    iconData: Icons.emoji_events,
  ),
  tournamentTop3(
    id: 'tournament_top3',
    title: 'Podium Finish',
    description: 'Finish in the top 3',
    iconData: Icons.emoji_events,
  ),
  tournamentRank1(
    id: 'tournament_rank1',
    title: 'Champion',
    description: 'Finish rank 1',
    iconData: Icons.emoji_events,
  ),
  firstDuelWin(
    id: 'first_duel_win',
    title: 'Worthy Opponent',
    description: 'Win your first duel',
    iconData: Icons.sports_kabaddi,
  ),
  selftestPerfect(
    id: 'selftest_perfect',
    title: 'Perfect Score',
    description: 'Score 25/25 on Self-Test',
    iconData: Icons.workspace_premium,
  ),
  firstArena(
    id: 'first_arena',
    title: 'Arena Creator',
    description: 'Create your first Arena',
    iconData: Icons.groups,
  ),
  firstLive(
    id: 'first_live',
    title: 'Live Player',
    description: 'Join your first Live Tournament',
    iconData: Icons.live_tv,
  ),
  earlyAdopter(
    id: 'early_adopter',
    title: 'Early Adopter',
    description: 'Joined Brainjamin at launch',
    iconData: Icons.rocket_launch,
  );

  const BrainjaminAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
  });

  final String id;
  final String title;
  final String description;
  final IconData iconData;

  static BrainjaminAchievement? fromId(String id) {
    for (final achievement in BrainjaminAchievement.values) {
      if (achievement.id == id) {
        return achievement;
      }
    }
    return null;
  }
}
