class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? achievementTitleId; // Achievement ID to use as title
  final String? achievementTitleName; // Achievement title text (for display without lookup)
  final int? customBackgroundTier;
  final DateTime lastUpdated;
  final LeaderboardStats stats;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.achievementTitleId,
    this.achievementTitleName,
    this.customBackgroundTier,
    required this.lastUpdated,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'achievementTitleId': achievementTitleId,
        'achievementTitleName': achievementTitleName,
        'customBackgroundTier': customBackgroundTier,
        'lastUpdated': lastUpdated.toIso8601String(),
        'stats': stats.toJson(),
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        userId: json['userId'] ?? '',
        displayName: json['displayName'] ?? 'Unknown Player',
        achievementTitleId: json['achievementTitleId'],
        achievementTitleName: json['achievementTitleName'],
        customBackgroundTier: json['customBackgroundTier'],
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'])
            : DateTime.now(),
        stats: LeaderboardStats.fromJson(json['stats'] ?? {}),
      );
}

class LeaderboardStats {
  final int level;
  final double totalXp;
  final int totalPlays;
  final int uniqueGamesPlayed;
  final int gamesOwned;
  final int achievementsUnlocked;
  final int currentStreak;
  final int longestStreak;

  LeaderboardStats({
    required this.level,
    required this.totalXp,
    required this.totalPlays,
    required this.uniqueGamesPlayed,
    required this.gamesOwned,
    required this.achievementsUnlocked,
    required this.currentStreak,
    required this.longestStreak,
  });

  Map<String, dynamic> toJson() => {
        'level': level,
        'totalXp': totalXp,
        'totalPlays': totalPlays,
        'uniqueGamesPlayed': uniqueGamesPlayed,
        'gamesOwned': gamesOwned,
        'achievementsUnlocked': achievementsUnlocked,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      };

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) =>
      LeaderboardStats(
        level: json['level'] ?? 1,
        totalXp: (json['totalXp'] is int)
            ? (json['totalXp'] as int).toDouble()
            : (json['totalXp'] ?? 0.0),
        totalPlays: json['totalPlays'] ?? 0,
        uniqueGamesPlayed: json['uniqueGamesPlayed'] ?? 0,
        gamesOwned: json['gamesOwned'] ?? 0,
        achievementsUnlocked: json['achievementsUnlocked'] ?? 0,
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
      );
}
