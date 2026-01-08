import 'package:quokka/models/board_game.dart';

enum AchievementTier { bronze, silver, gold }

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementTier tier;
  final int xpReward;
  final String category;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.xpReward,
    required this.category,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  Achievement copyWith({DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      tier: tier,
      xpReward: xpReward,
      category: category,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };
}

class XpLogEntry {
  final DateTime date;
  final String reason;
  final int amount;

  XpLogEntry({required this.date, required this.reason, required this.amount});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'reason': reason,
        'amount': amount,
      };

  factory XpLogEntry.fromJson(Map<String, dynamic> json) => XpLogEntry(
        date: DateTime.parse(json['date']),
        reason: json['reason'],
        amount: json['amount'],
      );
}

class UserStats {
  final int totalXp;
  final int level;
  final List<XpLogEntry> xpHistory;
  final List<String> unlockedAchievementIds;
  
  // Counters for achievements
  final int soldCount;
  final int lendedCount;
  final int wishlistConversions;
  final int totalPlays;
  final int totalWins;

  UserStats({
    this.totalXp = 0,
    this.level = 1,
    this.xpHistory = const [],
    this.unlockedAchievementIds = const [],
    this.soldCount = 0,
    this.lendedCount = 0,
    this.wishlistConversions = 0,
    this.totalPlays = 0,
    this.totalWins = 0,
  });

  int get xpForNextLevel => 99 + (level + 1);
  
  UserStats copyWith({
    int? totalXp,
    int? level,
    List<XpLogEntry>? xpHistory,
    List<String>? unlockedAchievementIds,
    int? soldCount,
    int? lendedCount,
    int? wishlistConversions,
    int? totalPlays,
    int? totalWins,
  }) {
    return UserStats(
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      xpHistory: xpHistory ?? this.xpHistory,
      unlockedAchievementIds: unlockedAchievementIds ?? this.unlockedAchievementIds,
      soldCount: soldCount ?? this.soldCount,
      lendedCount: lendedCount ?? this.lendedCount,
      wishlistConversions: wishlistConversions ?? this.wishlistConversions,
      totalPlays: totalPlays ?? this.totalPlays,
      totalWins: totalWins ?? this.totalWins,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
        'level': level,
        'xpHistory': xpHistory.map((e) => e.toJson()).toList(),
        'unlockedAchievementIds': unlockedAchievementIds,
        'soldCount': soldCount,
        'lendedCount': lendedCount,
        'wishlistConversions': wishlistConversions,
        'totalPlays': totalPlays,
        'totalWins': totalWins,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalXp: json['totalXp'] ?? 0,
        level: json['level'] ?? 1,
        xpHistory: (json['xpHistory'] as List?)?.map((e) => XpLogEntry.fromJson(e)).toList() ?? [],
        unlockedAchievementIds: List<String>.from(json['unlockedAchievementIds'] ?? []),
        soldCount: json['soldCount'] ?? 0,
        lendedCount: json['lendedCount'] ?? 0,
        wishlistConversions: json['wishlistConversions'] ?? 0,
        totalPlays: json['totalPlays'] ?? 0,
        totalWins: json['totalWins'] ?? 0,
      );
}
