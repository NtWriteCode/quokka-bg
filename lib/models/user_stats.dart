
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
  final double amount;

  XpLogEntry({required this.date, required this.reason, required this.amount});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'reason': reason,
        'amount': amount,
      };

  factory XpLogEntry.fromJson(Map<String, dynamic> json) => XpLogEntry(
        date: DateTime.parse(json['date']),
        reason: json['reason'],
        amount: (json['amount'] is int) ? (json['amount'] as int).toDouble() : (json['amount'] ?? 0.0),
      );
}

class UserStats {
  final double totalXp; // Changed to double for fractional XP
  final int level;
  final List<XpLogEntry> xpHistory;
  final List<String> unlockedAchievementIds;
  
  // Counters for achievements
  final int soldCount;
  final int lendedCount;
  final int wishlistConversions;
  final int totalPlays;
  final int totalWins;
  
  // Daily login and streak tracking
  final DateTime? lastLoginDate;
  final DateTime? lastPlayDate; // Last date a game was played
  final int consecutiveDays; // Consecutive days playing games (for streak bonus)
  final double streakBonus; // Current streak bonus percentage (0.0 to 1.0 = 0% to 100%)
  
  // Customization
  final String? customTitle; // null means use level-based title
  final int? customBackgroundTier; // null means use level-based background
  
  // Leaderboard
  final String userId; // Unique identifier for leaderboard
  final String displayName; // Public display name for leaderboard

  UserStats({
    this.totalXp = 0.0,
    this.level = 1,
    this.xpHistory = const [],
    this.unlockedAchievementIds = const [],
    this.soldCount = 0,
    this.lendedCount = 0,
    this.wishlistConversions = 0,
    this.totalPlays = 0,
    this.totalWins = 0,
    this.lastLoginDate,
    this.lastPlayDate,
    this.consecutiveDays = 0,
    this.streakBonus = 0.0,
    this.customTitle,
    this.customBackgroundTier,
    String? userId,
    String? displayName,
  }) : userId = userId ?? '',
       displayName = displayName ?? '';

  /// Calculate XP required to reach a specific level from the previous level
  /// For example: getXpRequiredForLevel(2) returns XP needed to go from level 1 to level 2
  static int getXpRequiredForLevel(int targetLevel) {
    return 90 + (targetLevel ~/ 10) * 5;
  }
  
  /// Calculate level and remaining XP from a total accumulated XP amount
  /// Returns a map with 'level' (int) and 'remainingXp' (double) keys
  static Map<String, num> calculateLevelFromTotalXp(double totalAccumulatedXp) {
    int level = 1;
    double remaining = totalAccumulatedXp;
    
    while (true) {
      int xpNeeded = getXpRequiredForLevel(level + 1);
      if (remaining < xpNeeded) break;
      remaining -= xpNeeded;
      level++;
    }
    
    return {'level': level, 'remainingXp': remaining};
  }
  
  int get xpForNextLevel => getXpRequiredForLevel(level + 1);
  
  UserStats copyWith({
    double? totalXp,
    int? level,
    List<XpLogEntry>? xpHistory,
    List<String>? unlockedAchievementIds,
    int? soldCount,
    int? lendedCount,
    int? wishlistConversions,
    int? totalPlays,
    int? totalWins,
    Object? lastLoginDate = _notProvided,
    Object? lastPlayDate = _notProvided,
    int? consecutiveDays,
    double? streakBonus,
    Object? customTitle = _notProvided,
    Object? customBackgroundTier = _notProvided,
    String? userId,
    String? displayName,
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
      lastLoginDate: lastLoginDate == _notProvided ? this.lastLoginDate : lastLoginDate as DateTime?,
      lastPlayDate: lastPlayDate == _notProvided ? this.lastPlayDate : lastPlayDate as DateTime?,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      streakBonus: streakBonus ?? this.streakBonus,
      customTitle: customTitle == _notProvided ? this.customTitle : customTitle as String?,
      customBackgroundTier: customBackgroundTier == _notProvided ? this.customBackgroundTier : customBackgroundTier as int?,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
    );
  }

  static const _notProvided = Object();

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
        'lastLoginDate': lastLoginDate?.toIso8601String(),
        'lastPlayDate': lastPlayDate?.toIso8601String(),
        'consecutiveDays': consecutiveDays,
        'streakBonus': streakBonus,
        'customTitle': customTitle,
        'customBackgroundTier': customBackgroundTier,
        'userId': userId,
        'displayName': displayName,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalXp: (json['totalXp'] is int) ? (json['totalXp'] as int).toDouble() : (json['totalXp'] ?? 0.0),
        level: json['level'] ?? 1,
        xpHistory: (json['xpHistory'] as List?)?.map((e) => XpLogEntry.fromJson(e)).toList() ?? [],
        unlockedAchievementIds: List<String>.from(json['unlockedAchievementIds'] ?? []),
        soldCount: json['soldCount'] ?? 0,
        lendedCount: json['lendedCount'] ?? 0,
        wishlistConversions: json['wishlistConversions'] ?? 0,
        lastLoginDate: json['lastLoginDate'] != null ? DateTime.parse(json['lastLoginDate']) : null,
        lastPlayDate: json['lastPlayDate'] != null ? DateTime.parse(json['lastPlayDate']) : null,
        consecutiveDays: json['consecutiveDays'] ?? 0,
        streakBonus: (json['streakBonus'] is int) ? (json['streakBonus'] as int).toDouble() : (json['streakBonus'] ?? 0.0),
        totalPlays: json['totalPlays'] ?? 0,
        totalWins: json['totalWins'] ?? 0,
        customTitle: json['customTitle'],
        customBackgroundTier: json['customBackgroundTier'],
        userId: json['userId'],
        displayName: json['displayName'],
      );
}
