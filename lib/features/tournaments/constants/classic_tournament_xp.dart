/// XP tiers for Classic tournaments. Mirrors `functions/src/shared/classicScoring.ts`.
/// If server tiers change, update both files.
final class ClassicTournamentXp {
  ClassicTournamentXp._();

  static const int rank1 = 500;
  static const int rank2to3 = 300;
  static const int rank4to10 = 200;
  static const int rank11to50 = 100;
  static const int completionFloor = 50;

  /// Returns XP awarded for a given rank (1-based).
  static int forRank(int rank) {
    if (rank < 1) {
      throw ArgumentError.value(rank, 'rank', 'must be >= 1');
    }
    if (rank == 1) {
      return rank1;
    }
    if (rank <= 3) {
      return rank2to3;
    }
    if (rank <= 10) {
      return rank4to10;
    }
    if (rank <= 50) {
      return rank11to50;
    }
    return completionFloor;
  }

  /// Tier rows for UI display: (rangeLabel, xp).
  /// Used by detail screen XP table.
  static const List<({String label, int xp})> tierRows = [
    (label: '1st', xp: rank1),
    (label: '2nd – 3rd', xp: rank2to3),
    (label: '4th – 10th', xp: rank4to10),
    (label: '11th – 50th', xp: rank11to50),
    (label: 'Everyone else', xp: completionFloor),
  ];
}
