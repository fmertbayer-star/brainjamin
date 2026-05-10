/// Firestore collection names used by the Brainjamin client.
/// Backend collection paths must stay in sync with this file.
class FirestoreCollections {
  FirestoreCollections._();

  // Identity & audience
  static const String users = 'users';
  static const String usersPublic = 'users_public';

  // Question pool
  static const String questionsPublic = 'questions_public';

  // Self-Test (Sprint 2)
  static const String selfTestSessions = 'self_test_sessions';
  static const String selfTestLeaderboard = 'self_test_leaderboard';

  // Daily
  static const String dailyAnswers = 'daily_answers';

  // Duel (Sprint 3)
  static const String duels = 'duels';
  static const String duelQuestions = 'duel_questions';

  // Reports (Sprint 2)
  static const String reports = 'reports';

  // Notifications (Sprint 2)
  static const String notifications = 'notifications';

  // Config / ops
  static const String aiConfig = 'ai_config';
  static const String legalDocs = 'legal_docs';
}
