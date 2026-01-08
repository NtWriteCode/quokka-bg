import 'package:bg_tracker/models/board_game.dart';
import 'package:bg_tracker/models/play_record.dart';
import 'package:bg_tracker/models/player.dart';
import 'package:intl/intl.dart';

enum StatsPeriod { week, month, year, total }

class StatsHelper {
  final List<BoardGame> games;
  final List<PlayRecord> plays;
  final List<Player> players;

  StatsHelper({required this.games, required this.plays, required this.players});

  // Basic counts
  int get ownedCount => games.where((g) => g.status == GameStatus.owned).length;
  int get soldCount => games.where((g) => g.status == GameStatus.sold).length;
  int get lendedCount => games.where((g) => g.status == GameStatus.lended).length;
  int get unownedCount => games.where((g) => g.status == GameStatus.unowned).length;
  int get wishlistCount => games.where((g) => g.status == GameStatus.wishlist).length;

  List<PlayRecord> getPlaysInPeriod(StatsPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case StatsPeriod.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return plays.where((p) => p.date.isAfter(startOfWeek)).toList();
      case StatsPeriod.month:
        return plays.where((p) => p.date.year == now.year && p.date.month == now.month).toList();
      case StatsPeriod.year:
        return plays.where((p) => p.date.year == now.year).toList();
      case StatsPeriod.total:
        return plays;
    }
  }

  // Plays per month for a chart (last 12 months)
  Map<String, int> getMonthlyPlayCounts() {
    final result = <String, int>{};
    final now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM').format(date);
      final count = plays.where((p) => p.date.year == date.year && p.date.month == date.month).length;
      result[key] = count;
    }
    return result;
  }

  // Top winners for a period
  Map<String, int> getTopWinners(StatsPeriod period, {int limit = 5}) {
    final periodPlays = getPlaysInPeriod(period);
    final winCounts = <String, int>{};

    for (var play in periodPlays) {
      if (play.winnerId != null) {
        winCounts[play.winnerId!] = (winCounts[play.winnerId!] ?? 0) + 1;
      }
    }

    final sortedWinners = winCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <String, int>{};
    for (var entry in sortedWinners.take(limit)) {
      final playerName = players.cast<Player?>().firstWhere((p) => p?.id == entry.key, orElse: () => null)?.name ?? 'Unknown';
      result[playerName] = entry.value;
    }
    return result;
  }

  // Most Played Games
  List<MapEntry<String, int>> getMostPlayedGames({int limit = 3}) {
    final counts = <String, int>{};
    for (var play in plays) {
      counts[play.gameName] = (counts[play.gameName] ?? 0) + 1;
    }
    return counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  // Least Played Games (from owned)
  List<MapEntry<String, int>> getLeastPlayedGames({int limit = 3}) {
    final owned = games.where((g) => g.status == GameStatus.owned).toList();
    final counts = <String, int>{};
    for (var game in owned) {
      counts[game.name] = plays.where((p) => p.gameId == game.id).length;
    }
    return counts.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  // Strongest game for each player
  Map<String, String> getPlayerStrongestGames() {
    final result = <String, String>{};
    for (var player in players) {
      final playerWins = plays.where((p) => p.winnerId == player.id);
      if (playerWins.isEmpty) {
        result[player.name] = 'No wins yet';
        continue;
      }

      final gameWinCounts = <String, int>{};
      for (var play in playerWins) {
        gameWinCounts[play.gameName] = (gameWinCounts[play.gameName] ?? 0) + 1;
      }

      final strongest = gameWinCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      result[player.name] = strongest.first.key;
    }
    return result;
  }
}
