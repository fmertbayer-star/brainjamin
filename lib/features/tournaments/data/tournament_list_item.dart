import 'live_tournament.dart';
import 'tournament.dart';

/// Row in the merged Tournaments tab list (Classic or Live).
sealed class TournamentListItem {
  const TournamentListItem();

  DateTime get startsAt;
}

final class TournamentListItemClassic extends TournamentListItem {
  const TournamentListItemClassic(this.tournament);

  final Tournament tournament;

  @override
  DateTime get startsAt => tournament.startsAt;
}

final class TournamentListItemLive extends TournamentListItem {
  const TournamentListItemLive(this.tournament);

  final LiveTournament tournament;

  @override
  DateTime get startsAt => tournament.startsAt;
}
