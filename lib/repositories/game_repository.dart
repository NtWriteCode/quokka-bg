import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:quokka/models/board_game.dart';
import 'package:quokka/models/play_record.dart';
import 'package:quokka/models/player.dart';
import 'package:quokka/models/user_stats.dart';
import 'package:quokka/models/leaderboard_entry.dart';
import 'package:quokka/services/sync_service.dart';
import 'package:quokka/services/achievement_service.dart';
import 'package:quokka/helpers/title_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class GameRepository extends ChangeNotifier {
  List<BoardGame> _ownedGames = [];
  List<Player> _players = [];
  List<PlayRecord> _playRecords = [];
  
  UserStats _userStats = UserStats();
  
  // Session Caches
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  final Map<String, Map<String, dynamic>> _detailsCache = {};
  final _syncService = SyncService();
  int _dataVersion = 0;
  bool _showUnownedGames = true;
  
  final StreamController<List<Achievement>> _unlockedController = StreamController.broadcast();
  Stream<List<Achievement>> get onAchievementsUnlocked => _unlockedController.stream;
  
  GameRepository();

  // Getters for in-memory access
  List<BoardGame> get ownedGames => List.unmodifiable(_ownedGames);
  List<Player> get players => List.unmodifiable(_players);
  List<PlayRecord> get playRecords => List.unmodifiable(_playRecords);
  bool get showUnownedGames => _showUnownedGames;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showUnownedGames = prefs.getBool('show_unowned_games') ?? true;
  }

  UserStats get userStats => _userStats;
  
  Future<void> addXp(double amount, String reason, {bool applyStreakBonus = false}) async {
    // Apply streak bonus if requested
    double finalAmount = amount;
    if (applyStreakBonus) {
      finalAmount = amount * (1.0 + _userStats.streakBonus);
    }
    
    double newXp = _userStats.totalXp + finalAmount;
    int oldLevel = _userStats.level;
    int newLevel = oldLevel;
    
    while (newXp >= UserStats.getXpRequiredForLevel(newLevel + 1)) {
      newXp -= UserStats.getXpRequiredForLevel(newLevel + 1);
      newLevel++;
    }
    
    _userStats = _userStats.copyWith(
      totalXp: newXp,
      level: newLevel,
      xpHistory: [
        XpLogEntry(date: DateTime.now(), reason: reason, amount: amount),
        ..._userStats.xpHistory,
      ].take(100).toList(), // Keep last 100 entries
    );
    await saveUserStats();
    
    // Check if level changed and trigger title/background notifications
    if (newLevel > oldLevel) {
      _notifyLevelUp(oldLevel, newLevel);
    }
  }

  // Stream controller for level-up events
  final StreamController<Map<String, dynamic>> _levelUpController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get onLevelUp => _levelUpController.stream;

  void _notifyLevelUp(int oldLevel, int newLevel) {
    // Broadcast level-up event with details
    _levelUpController.add({
      'oldLevel': oldLevel,
      'newLevel': newLevel,
      'newTitle': _getTitleForLevel(newLevel),
      'newBackgroundTier': (newLevel / 5).floor(),
      'xpForNext': UserStats.getXpRequiredForLevel(newLevel + 1),
    });
  }
  
  String _getTitleForLevel(int level) {
    return TitleHelper.getTitleForLevel(level);
  }
  
  /// Check and award daily login bonus
  Future<void> checkDailyLoginBonus() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_userStats.lastLoginDate == null) {
      // First login ever
      await addXp(1.0, 'Daily Login Bonus');
      _userStats = _userStats.copyWith(lastLoginDate: now);
      await saveUserStats();
      return;
    }
    
    final lastLogin = DateTime(
      _userStats.lastLoginDate!.year,
      _userStats.lastLoginDate!.month,
      _userStats.lastLoginDate!.day,
    );
    
    if (today.isAfter(lastLogin)) {
      // It's a new day, award bonus
      await addXp(1.0, 'Daily Login Bonus');
      _userStats = _userStats.copyWith(lastLoginDate: now);
      await saveUserStats();
    }
  }
  
  /// Update streak bonus based on play activity
  /// Call this when a game is played
  Future<void> updateStreakBonus() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_userStats.lastPlayDate == null) {
      // First play ever
      _userStats = _userStats.copyWith(
        lastPlayDate: now,
        consecutiveDays: 1,
        streakBonus: 0.1, // 10% bonus after first day
      );
      await saveUserStats();
      return;
    }
    
    final lastPlay = DateTime(
      _userStats.lastPlayDate!.year,
      _userStats.lastPlayDate!.month,
      _userStats.lastPlayDate!.day,
    );
    
    final daysDifference = today.difference(lastPlay).inDays;
    
    if (daysDifference == 0) {
      // Same day, no change
      return;
    } else if (daysDifference == 1) {
      // Consecutive day! Increase streak
      final newConsecutiveDays = _userStats.consecutiveDays + 1;
      final newStreakBonus = (newConsecutiveDays * 0.1).clamp(0.0, 1.0); // Max 100%
      
      _userStats = _userStats.copyWith(
        lastPlayDate: now,
        consecutiveDays: newConsecutiveDays,
        streakBonus: newStreakBonus,
      );
      await saveUserStats();
    } else {
      // Missed days! Decrease streak by 40% per day missed
      double newStreakBonus = _userStats.streakBonus;
      for (int i = 1; i < daysDifference; i++) {
        newStreakBonus = (newStreakBonus - 0.4).clamp(0.0, 1.0);
      }
      
      // Calculate new consecutive days based on bonus
      final newConsecutiveDays = (newStreakBonus / 0.1).round();
      
      _userStats = _userStats.copyWith(
        lastPlayDate: now,
        consecutiveDays: newConsecutiveDays,
        streakBonus: newStreakBonus,
      );
      await saveUserStats();
    }
  }

  Future<void> checkAchievements() async {
    final newUnlocks = <Achievement>[];
    final all = AchievementService.allAchievements;
    
    for (final ach in all) {
      if (_userStats.unlockedAchievementIds.contains(ach.id)) continue;
      
      bool shouldUnlock = false;
      switch (ach.id) {
        case 'collector_5': shouldUnlock = _ownedGames.where((g) => g.status == GameStatus.owned).length >= 5; break;
        case 'collector_25': shouldUnlock = _ownedGames.where((g) => g.status == GameStatus.owned).length >= 25; break;
        case 'collector_100': shouldUnlock = _ownedGames.where((g) => g.status == GameStatus.owned).length >= 100; break;
        case 'sold_1': shouldUnlock = _userStats.soldCount >= 1; break;
        case 'sold_5': shouldUnlock = _userStats.soldCount >= 5; break;
        case 'lend_1': shouldUnlock = _userStats.lendedCount >= 1; break;
        case 'lend_10': shouldUnlock = _userStats.lendedCount >= 10; break;
        case 'plays_10': shouldUnlock = _userStats.totalPlays >= 10; break;
        case 'win_1': shouldUnlock = _userStats.totalWins >= 1; break;
        case 'players_5': shouldUnlock = _players.length >= 5; break;
        case 'players_10': shouldUnlock = _players.length >= 10; break;
        case 'players_20': shouldUnlock = _players.length >= 20; break;
        case 'wish_1': shouldUnlock = _ownedGames.any((g) => g.isWishlist); break;
        case 'wish_to_own_1': shouldUnlock = _userStats.wishlistConversions >= 1; break;
        
        // Variety achievements
        case 'distinct_50': {
          final uniqueGames = _playRecords.map((p) => p.gameId).toSet();
          shouldUnlock = uniqueGames.length >= 50;
          break;
        }
        
        // Expansionist achievements
        case 'expansion_1': 
          shouldUnlock = _ownedGames.where((g) => g.isExpansion && g.status == GameStatus.owned).isNotEmpty; break;
        case 'expansion_10': 
          shouldUnlock = _ownedGames.where((g) => g.isExpansion && g.status == GameStatus.owned).length >= 10; break;
        case 'expansion_30': 
          shouldUnlock = _ownedGames.where((g) => g.isExpansion && g.status == GameStatus.owned).length >= 30; break;
        case 'expansion_play_1': 
          shouldUnlock = _playRecords.any((p) => p.expansionIds.isNotEmpty); break;
        case 'expansion_play_3': 
          shouldUnlock = _playRecords.any((p) => p.expansionIds.length >= 3); break;
        case 'expansion_variety_5': {
          final parentIds = _ownedGames
              .where((g) => g.isExpansion && g.status == GameStatus.owned && g.parentGameId != null)
              .map((g) => g.parentGameId)
              .toSet();
          shouldUnlock = parentIds.length >= 5;
          break;
        }
        
        // Complexity achievements
        case 'complexity_simplest': {
          final simplestGame = getSimplestGame();
          if (simplestGame != null) {
            shouldUnlock = _playRecords.any((p) => p.gameId == simplestGame.id);
          }
          break;
        }
        case 'complexity_hardest': {
          final hardestGame = getHardestGame();
          if (hardestGame != null) {
            shouldUnlock = _playRecords.any((p) => p.gameId == hardestGame.id);
          }
          break;
        }
        
        // Rating achievements
        case 'rating_lowest': {
          final lowestRated = getLowestRatedGame();
          if (lowestRated != null) {
            shouldUnlock = _playRecords.any((p) => p.gameId == lowestRated.id);
          }
          break;
        }
        case 'rating_highest': {
          final highestRated = getHighestRatedGame();
          if (highestRated != null) {
            shouldUnlock = _playRecords.any((p) => p.gameId == highestRated.id);
          }
          break;
        }
        
        // Player count achievements
        case 'solo_player': {
          // Check if any play has exactly 1 player (solo)
          shouldUnlock = _playRecords.any((p) => p.playerScores.length == 1);
          break;
        }
        case 'max_players': {
          // Check if any play was with max players (and max is 3+)
          for (final play in _playRecords) {
            final game = _ownedGames.firstWhere(
              (g) => g.id == play.gameId,
              orElse: () => BoardGame(id: '', name: '', dateAdded: DateTime.now()),
            );
            if (game.maxPlayers != null && game.maxPlayers! >= 3) {
              if (play.playerScores.length == game.maxPlayers) {
                shouldUnlock = true;
                break;
              }
            }
          }
          break;
        }
        
        // Purchase achievements
        case 'buy_new_game': {
          // Check if any owned game was purchased new
          shouldUnlock = _ownedGames.any((g) => 
            (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
            g.isNew == true
          );
          break;
        }
        case 'buy_used_game': {
          // Check if any owned game was purchased used
          shouldUnlock = _ownedGames.any((g) => 
            (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
            g.isNew == false
          );
          break;
        }
        
        // Winning streak
        case 'winning_streak_3': {
          shouldUnlock = _checkWinningStreak(3);
          break;
        }
        
        // Close call
        case 'close_call': {
          shouldUnlock = _checkCloseCall();
          break;
        }
        
        // Game master
        case 'game_master': {
          final gamePlayCounts = <String, int>{};
          for (final play in _playRecords) {
            gamePlayCounts[play.gameId] = (gamePlayCounts[play.gameId] ?? 0) + 1;
          }
          shouldUnlock = gamePlayCounts.values.any((count) => count >= 10);
          break;
        }
        
        // Player count achievements
        case 'play_6_players': {
          shouldUnlock = _playRecords.any((p) => p.playerScores.length >= 6);
          break;
        }
        case 'play_10_players': {
          shouldUnlock = _playRecords.any((p) => p.playerScores.length >= 10);
          break;
        }
        case 'regular_crew': {
          shouldUnlock = _checkRegularCrew();
          break;
        }
        
        // Player count ownership achievements
        case 'own_solo_game': {
          // Check if any owned game is solo-only (min=1, max=1)
          shouldUnlock = _ownedGames.any((g) => 
            (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
            g.minPlayers == 1 && 
            g.maxPlayers == 1
          );
          break;
        }
        case 'own_duo_game': {
          // Check if any owned game is 2-player only (min=2, max=2)
          shouldUnlock = _ownedGames.any((g) => 
            (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
            g.minPlayers == 2 && 
            g.maxPlayers == 2
          );
          break;
        }
        case 'own_party_game': {
          // Check if any owned game supports 8+ players
          shouldUnlock = _ownedGames.any((g) => 
            (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
            g.maxPlayers != null && 
            g.maxPlayers! >= 8
          );
          break;
        }
        
        // Collection variety achievements
        case 'decade_collector': {
          final decades = _ownedGames
              .where((g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
                           g.yearPublished != null)
              .map((g) => (g.yearPublished! / 10).floor() * 10)
              .toSet();
          shouldUnlock = decades.length >= 3;
          break;
        }
        case 'vintage_collector': {
          shouldUnlock = _ownedGames.any((g) => 
            (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
            g.yearPublished != null && 
            g.yearPublished! <= 1990
          );
          break;
        }
        case 'complete_set': {
          shouldUnlock = _checkCompleteSet();
          break;
        }
        
        // Expansion achievements
        case 'expansion_single_game': {
          final expansionsByParent = <String, int>{};
          for (final game in _ownedGames) {
            if (game.isExpansion && 
                game.status == GameStatus.owned && 
                game.parentGameId != null) {
              expansionsByParent[game.parentGameId!] = 
                  (expansionsByParent[game.parentGameId!] ?? 0) + 1;
            }
          }
          shouldUnlock = expansionsByParent.values.any((count) => count >= 5);
          break;
        }
        
        // Meta achievements
        case 'achievement_hunter_25': {
          shouldUnlock = _userStats.unlockedAchievementIds.length >= 25;
          break;
        }
        case 'weekend_warrior': {
          shouldUnlock = _checkWeekendWarrior();
          break;
        }
        
        // Collection expansion achievements (20+ games required)
        // Auto-complete if user has extreme values that are nearly impossible to beat
        case 'buy_new_best_rated': {
          final ownedCount = _ownedGames.where((g) => g.status == GameStatus.owned || g.status == GameStatus.lended).length;
          if (ownedCount >= 20) {
            final highest = getHighestRatedGame();
            if (highest != null && highest.averageRating != null && highest.averageRating! >= 9.0) {
              shouldUnlock = true; // Auto-complete for rating >= 9.0
            }
          }
          break;
        }
        case 'buy_new_worst_rated': {
          final ownedCount = _ownedGames.where((g) => g.status == GameStatus.owned || g.status == GameStatus.lended).length;
          if (ownedCount >= 20) {
            final lowest = getLowestRatedGame();
            if (lowest != null && lowest.averageRating != null && lowest.averageRating! <= 2.0) {
              shouldUnlock = true; // Auto-complete for rating <= 2.0
            }
          }
          break;
        }
        case 'buy_new_most_complex': {
          final ownedCount = _ownedGames.where((g) => g.status == GameStatus.owned || g.status == GameStatus.lended).length;
          if (ownedCount >= 20) {
            final hardest = getHardestGame();
            if (hardest != null && hardest.averageWeight != null && hardest.averageWeight! >= 4.5) {
              shouldUnlock = true; // Auto-complete for weight >= 4.5
            }
          }
          break;
        }
        case 'buy_new_least_complex': {
          final ownedCount = _ownedGames.where((g) => g.status == GameStatus.owned || g.status == GameStatus.lended).length;
          if (ownedCount >= 20) {
            final simplest = getSimplestGame();
            if (simplest != null && simplest.averageWeight != null && simplest.averageWeight! <= 1.2) {
              shouldUnlock = true; // Auto-complete for weight <= 1.2
            }
          }
          break;
        }
      }
      
      if (shouldUnlock) {
        newUnlocks.add(ach);
      }
    }
    
    if (newUnlocks.isNotEmpty) {
      _userStats = _userStats.copyWith(
        unlockedAchievementIds: [
          ..._userStats.unlockedAchievementIds,
          ...newUnlocks.map((e) => e.id),
        ],
      );
      for (final ach in newUnlocks) {
        await addXp(ach.xpReward.toDouble(), 'Achievement: ${ach.title}');
      }
      _unlockedController.add(newUnlocks);
      await saveUserStats();
    }
  }

  /// Check purchase achievements when a new game is added
  /// This checks if the new game breaks records for best/worst rated or most/least complex
  Future<void> _checkPurchaseAchievements(BoardGame newGame) async {
    // Only check if we have 20+ games (excluding the new one)
    final ownedGames = _ownedGames.where((g) => 
      (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
      g.id != newGame.id
    ).toList();
    
    if (ownedGames.length < 20) return;
    
    final newUnlocks = <Achievement>[];
    final all = AchievementService.allAchievements;
    
    // Check if new game is the highest rated
    if (newGame.averageRating != null && 
        !_userStats.unlockedAchievementIds.contains('buy_new_best_rated')) {
      final currentBest = ownedGames
          .where((g) => g.averageRating != null)
          .fold<double?>(null, (max, g) => max == null || g.averageRating! > max ? g.averageRating : max);
      
      // Unlock if new game beats current best, OR if new game is >= 9.0 (extremely high)
      if ((currentBest != null && newGame.averageRating! > currentBest) ||
          newGame.averageRating! >= 9.0) {
        final ach = all.firstWhere((a) => a.id == 'buy_new_best_rated');
        newUnlocks.add(ach);
      }
    }
    
    // Check if new game is the lowest rated
    if (newGame.averageRating != null && 
        !_userStats.unlockedAchievementIds.contains('buy_new_worst_rated')) {
      final currentWorst = ownedGames
          .where((g) => g.averageRating != null)
          .fold<double?>(null, (min, g) => min == null || g.averageRating! < min ? g.averageRating : min);
      
      // Unlock if new game beats current worst, OR if new game is <= 2.0 (extremely low)
      if ((currentWorst != null && newGame.averageRating! < currentWorst) ||
          newGame.averageRating! <= 2.0) {
        final ach = all.firstWhere((a) => a.id == 'buy_new_worst_rated');
        newUnlocks.add(ach);
      }
    }
    
    // Check if new game is the most complex
    if (newGame.averageWeight != null && 
        !_userStats.unlockedAchievementIds.contains('buy_new_most_complex')) {
      final currentMost = ownedGames
          .where((g) => g.averageWeight != null)
          .fold<double?>(null, (max, g) => max == null || g.averageWeight! > max ? g.averageWeight : max);
      
      // Unlock if new game beats current most, OR if new game is >= 4.5 (extremely complex)
      if ((currentMost != null && newGame.averageWeight! > currentMost) ||
          newGame.averageWeight! >= 4.5) {
        final ach = all.firstWhere((a) => a.id == 'buy_new_most_complex');
        newUnlocks.add(ach);
      }
    }
    
    // Check if new game is the least complex
    if (newGame.averageWeight != null && 
        !_userStats.unlockedAchievementIds.contains('buy_new_least_complex')) {
      final currentLeast = ownedGames
          .where((g) => g.averageWeight != null)
          .fold<double?>(null, (min, g) => min == null || g.averageWeight! < min ? g.averageWeight : min);
      
      // Unlock if new game beats current least, OR if new game is <= 1.2 (extremely simple)
      if ((currentLeast != null && newGame.averageWeight! < currentLeast) ||
          newGame.averageWeight! <= 1.2) {
        final ach = all.firstWhere((a) => a.id == 'buy_new_least_complex');
        newUnlocks.add(ach);
      }
    }
    
    // Award achievements
    if (newUnlocks.isNotEmpty) {
      _userStats = _userStats.copyWith(
        unlockedAchievementIds: [
          ..._userStats.unlockedAchievementIds,
          ...newUnlocks.map((e) => e.id),
        ],
      );
      for (final ach in newUnlocks) {
        await addXp(ach.xpReward.toDouble(), 'Achievement: ${ach.title}');
      }
      _unlockedController.add(newUnlocks);
      await saveUserStats();
    }
  }

  Future<void> recalculateXp() async {
    await _preSaveSync();
    
    double totalXp = 0.0;
    
    // 1. Calculate XP from games (base XP without streak bonus)
    for (final game in _ownedGames) {
      switch (game.status) {
        case GameStatus.owned:
          totalXp += 10.0;
          break;
        case GameStatus.wishlist:
          totalXp += 1.0;
          break;
        case GameStatus.lended:
          totalXp += 10.0 + 5.0; // owned once + lent once
          break;
        case GameStatus.sold:
          totalXp += 10.0 + 3.0; // owned once + sold once
          break;
        case GameStatus.unowned:
          // No XP
          break;
      }
    }
    
    // 2. Add XP from wishlist conversions (use existing counter)
    totalXp += _userStats.wishlistConversions * 5.0;
    
    // 3. Calculate XP from plays (base XP - we can't retroactively apply streak bonuses)
    // Note: During recalculation, we ignore streak bonuses since we don't have historical streak data
    for (final play in _playRecords) {
      totalXp += 3.0 * play.playerScores.length;
    }
    
    // 4. Calculate XP from achievements
    final allAchievements = AchievementService.allAchievements;
    for (final achievementId in _userStats.unlockedAchievementIds) {
      final achievement = allAchievements.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => Achievement(
          id: achievementId,
          title: '',
          description: '',
          tier: AchievementTier.bronze,
          xpReward: 0,
          category: '',
        ),
      );
      totalXp += achievement.xpReward.toDouble();
    }
    
    // 5. Calculate level from total XP using centralized calculation
    final levelData = UserStats.calculateLevelFromTotalXp(totalXp);
    final level = levelData['level']! as int;
    final remaining = levelData['remainingXp']! as double;
    
    // 6. Recalculate counters from source data
    final soldCount = _ownedGames.where((g) => g.status == GameStatus.sold).length;
    final lendedCount = _ownedGames.where((g) => g.status == GameStatus.lended).length;
    final totalPlays = _playRecords.length;
    final totalWins = _playRecords.where((p) => p.winnerId != null).length;
    
    // 7. Update user stats
    _userStats = _userStats.copyWith(
      totalXp: remaining,
      level: level,
      xpHistory: [
        XpLogEntry(
          date: DateTime.now(),
          reason: 'XP Recalculated',
          amount: totalXp,
        ),
      ],
      soldCount: soldCount,
      lendedCount: lendedCount,
      totalPlays: totalPlays,
      totalWins: totalWins,
      // Keep wishlistConversions as is (can't recalculate)
    );
    
    await saveUserStats();
    notifyListeners();
    
    // Trigger level-up notification
    _notifyLevelUp(1, level);
  }

  Future<void> setShowUnownedGames(bool show) async {
    _showUnownedGames = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_unowned_games', show);
  }

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/games.json');
  }

  Future<File> get _playersFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/players.json');
  }

  Future<File> get _playsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/plays.json');
  }

  Future<File> get _metaFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/metadata.json');
  }

  Future<File> get _statsFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_stats.json');
  }

  Future<void> _loadLocalVersion() async {
    try {
      final file = await _metaFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        _dataVersion = json['version'] ?? 0;
      }
    } catch (e) {
      _dataVersion = 0;
    }
  }

  Future<void> _saveLocalVersion() async {
    final file = await _metaFile;
    await file.writeAsString(jsonEncode({'version': _dataVersion}));
  }

  Future<void> loadGames() async {
    try {
      await loadSettings();
      await _loadLocalVersion();
      final directory = await getApplicationDocumentsDirectory();
      
      // Attempt Sync Down before logic
      try {
        final downloaded = await _syncService.sync(directory, _dataVersion);
        if (downloaded) {
          await _loadLocalVersion(); // Reload version from the downloaded metadata.json
        }
      } catch (e) {
        print('DEBUG: Sync failed during load: $e');
      }

      final file = await _localFile;
      if (!await file.exists()) {
        _ownedGames = [];
      } else {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _ownedGames = jsonList.map((e) => BoardGame.fromJson(e)).toList();
      }
      
      await loadPlayers();
      await loadPlays();
      await loadUserStats();
      
      // Check achievements after loading (for auto-unlocks)
      await checkAchievements();
      
      notifyListeners();
      
      // Upload leaderboard entry after loading if feature is enabled
      // This ensures the leaderboard is updated on app start
      try {
        final leaderboardEnabled = await _syncService.isLeaderboardEnabled();
        if (leaderboardEnabled) {
          await uploadLeaderboardEntry();
        }
      } catch (e) {
        print('DEBUG: Leaderboard upload after load failed: $e');
      }
    } catch (e) {
      print('DEBUG: Error loading games: $e');
      _ownedGames = [];
    }
  }

  Future<void> loadPlayers() async {
    try {
      final file = await _playersFile;
      if (!await file.exists()) {
        _players = [];
        return;
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      _players = jsonList.map((e) => Player.fromJson(e)).toList();
    } catch (e) {
      print('DEBUG: Error loading players: $e');
      _players = [];
    }
  }

  Future<void> loadPlays() async {
    try {
      final file = await _playsFile;
      if (!await file.exists()) {
        _playRecords = [];
        return;
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      _playRecords = jsonList.map((e) => PlayRecord.fromJson(e)).toList();
    } catch (e) {
      print('DEBUG: Error loading plays: $e');
      _playRecords = [];
    }
  }

  Future<void> loadUserStats() async {
    try {
      final file = await _statsFile;
      if (!await file.exists()) {
        _userStats = UserStats();
        return;
      }
      final contents = await file.readAsString();
      _userStats = UserStats.fromJson(jsonDecode(contents));
    } catch (e) {
      print('DEBUG: Error loading stats: $e');
      _userStats = UserStats();
    }
  }

  Future<void> saveUserStats() async {
    try {
      final file = await _statsFile;
      await file.writeAsString(jsonEncode(_userStats.toJson()));
      await _postSaveSync();
      notifyListeners();
    } catch (e) {
      print('DEBUG: Error saving stats: $e');
    }
  }

  Future<void> updateUserStatsCustomization(UserStats updatedStats) async {
    _userStats = updatedStats;
    await saveUserStats();
  }

  Future<void> triggerManualSyncUp() async {
    final directory = await getApplicationDocumentsDirectory();
    await _syncService.upload(directory, _dataVersion);
    
    // Also upload leaderboard entry if enabled
    final leaderboardEnabled = await _syncService.isLeaderboardEnabled();
    if (leaderboardEnabled) {
      await uploadLeaderboardEntry();
    }
  }

  @override
  void dispose() {
    _unlockedController.close();
    _levelUpController.close();
    super.dispose();
  }

  Future<void> _preSaveSync() async {
    final directory = await getApplicationDocumentsDirectory();
    final downloaded = await _syncService.sync(directory, _dataVersion);
    if (downloaded) {
      // Reload everything from disk to memory
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _ownedGames = jsonList.map((e) => BoardGame.fromJson(e)).toList();
      }
      await loadPlayers();
      await loadPlays();
      await loadUserStats();
      await _loadLocalVersion();
      notifyListeners();
    }
  }

  Future<void> _postSaveSync() async {
    _dataVersion++;
    await _saveLocalVersion();
    final directory = await getApplicationDocumentsDirectory();
    
    // Upload all JSONs including user_stats
    final files = ['games.json', 'players.json', 'plays.json', 'user_stats.json'];
    for (final fileName in files) {
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        // This is handled by sync service upload typically, but let's ensure upload() takes all
      }
    }
    await _syncService.upload(directory, _dataVersion);
    
    // Also upload leaderboard entry if enabled
    final leaderboardEnabled = await _syncService.isLeaderboardEnabled();
    if (leaderboardEnabled) {
      await uploadLeaderboardEntry();
    }
  }

  Future<void> saveGames() async {
    try {
      final file = await _localFile;
      final jsonList = _ownedGames.map((g) => g.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      await _postSaveSync();
      notifyListeners();
    } catch (e) {
       print('DEBUG: Error saving games: $e');
     }
  }

  Future<void> savePlayers() async {
    try {
      final file = await _playersFile;
      final jsonList = _players.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      await _postSaveSync();
      notifyListeners();
    } catch (e) {
      print('DEBUG: Error saving players: $e');
    }
  }

  Future<void> savePlays() async {
    try {
      final file = await _playsFile;
      final jsonList = _playRecords.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      await _postSaveSync();
      notifyListeners();
    } catch (e) {
      print('DEBUG: Error saving plays: $e');
    }
  }

  Future<void> addGame(BoardGame game) async {
    await _preSaveSync();
    _ownedGames.add(game);
    await saveGames();
    if (game.isWishlist) {
      await addXp(1.0, 'Added to Wishlist: ${game.name}');
    } else {
      await addXp(10.0, 'New Collection Entry: ${game.name}');
      // Check if this new game breaks any collection records
      if (game.status == GameStatus.owned || game.status == GameStatus.lended) {
        await _checkPurchaseAchievements(game);
      }
    }
    await checkAchievements();
  }

  Future<void> addPlayer(Player player) async {
    await _preSaveSync();
    _players.add(player);
    await savePlayers();
  }

  Future<void> removePlayer(String id) async {
    await _preSaveSync();
    _players.removeWhere((p) => p.id == id);
    await savePlayers();
  }

  Future<void> updatePlayer(Player updatedPlayer) async {
    await _preSaveSync();
    final index = _players.indexWhere((p) => p.id == updatedPlayer.id);
    if (index != -1) {
      _players[index] = updatedPlayer;
      await savePlayers();
    }
  }

  Future<void> addPlayRecord(PlayRecord record) async {
    await _preSaveSync();
    _playRecords.add(record);
    await savePlays();
    
    // Update streak bonus before awarding XP
    await updateStreakBonus();
    
    int playerCount = record.playerScores.length;
    await addXp(3.0 * playerCount, 'Played ${record.gameName} with $playerCount people', applyStreakBonus: true);
    
    _userStats = _userStats.copyWith(
      totalPlays: _userStats.totalPlays + 1,
      totalWins: record.winnerId != null ? _userStats.totalWins + 1 : _userStats.totalWins,
    );
    
    await checkAchievements();
  }

  Future<void> removePlayRecord(String id) async {
    await _preSaveSync();
    _playRecords.removeWhere((r) => r.id == id);
    await savePlays();
  }

  Future<void> updatePlayRecord(PlayRecord updatedRecord) async {
    await _preSaveSync();
    final index = _playRecords.indexWhere((r) => r.id == updatedRecord.id);
    if (index != -1) {
      _playRecords[index] = updatedRecord;
      await savePlays();
    }
  }

  List<BoardGame> getRecentlyPlayedGames({int limit = 5}) {
    final sortedPlays = List<PlayRecord>.from(_playRecords)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    final uniqueIds = <String>{};
    final recentGames = <BoardGame>[];
    
    for (var play in sortedPlays) {
      if (uniqueIds.add(play.gameId)) {
        final game = _ownedGames.cast<BoardGame?>().firstWhere(
          (g) => g?.id == play.gameId,
          orElse: () => null,
        );
        if (game != null) {
          recentGames.add(game);
        }
      }
      if (recentGames.length >= limit) break;
    }
    return recentGames;
  }

  int getPlayCountForGame(String gameId) {
    return _playRecords.where((p) => p.gameId == gameId).length;
  }

  int getWinCountForPlayer(String playerId) {
    return _playRecords.where((p) => p.winnerId == playerId).length;
  }

  String? getStrongestGameForPlayer(String playerId) {
    final wins = _playRecords.where((p) => p.winnerId == playerId).toList();
    if (wins.isEmpty) return null;

    final counts = <String, int>{};
    for (var play in wins) {
      counts[play.gameName] = (counts[play.gameName] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.first.key;
  }

  Future<void> updateGame(BoardGame updatedGame) async {
    await _preSaveSync();
    final index = _ownedGames.indexWhere((g) => g.id == updatedGame.id);
    if (index != -1) {
      final oldGame = _ownedGames[index];
      _ownedGames[index] = updatedGame;
      await _handleStatusTransition(oldGame, updatedGame.status);
      await saveGames();
    }
  }

  Future<void> updateGameStatus(String id, GameStatus newStatus) async {
    await _preSaveSync();
    final index = _ownedGames.indexWhere((g) => g.id == id);
    if (index != -1) {
      final oldGame = _ownedGames[index];
      _ownedGames[index] = _ownedGames[index].copyWith(status: newStatus);
      await _handleStatusTransition(oldGame, newStatus);
      await saveGames();
    }
  }

  Future<void> _handleStatusTransition(BoardGame oldGame, GameStatus newStatus) async {
    if (oldGame.status == newStatus) return;

    if (oldGame.isWishlist && newStatus != GameStatus.wishlist) {
      _userStats = _userStats.copyWith(wishlistConversions: _userStats.wishlistConversions + 1);
      await addXp(5.0, 'Got it! Wishlist -> Collection: ${oldGame.name}');
      // Check if this newly acquired game breaks any collection records
      if (newStatus == GameStatus.owned || newStatus == GameStatus.lended) {
        await _checkPurchaseAchievements(oldGame);
      }
    } else if (newStatus == GameStatus.sold) {
      _userStats = _userStats.copyWith(soldCount: _userStats.soldCount + 1);
      await addXp(3.0, 'Sold: ${oldGame.name}');
    } else if (newStatus == GameStatus.lended) {
      _userStats = _userStats.copyWith(lendedCount: _userStats.lendedCount + 1);
      await addXp(5.0, 'Lent: ${oldGame.name}');
    }
    await checkAchievements();
  }

  Future<void> removeGame(String id) async {
    await _preSaveSync();
    _ownedGames.removeWhere((g) => g.id == id);
    await saveGames();
  }

  Future<List<Map<String, dynamic>>> searchBgg(String query) async {
    final lowerQuery = query.toLowerCase().trim();
    if (_searchCache.containsKey(lowerQuery)) {
      return _searchCache[lowerQuery]!;
    }

    final uri = Uri.parse('https://boardgamegeek.com/search/boardgame')
        .replace(queryParameters: {
      'q': query,
      'nosession': '1',
      'showcount': '50',
    });

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0',
          'Accept': 'application/json, text/plain, */*',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['items'] is List) {
           final results = List<Map<String, dynamic>>.from(data['items']);
           _searchCache[lowerQuery] = results;
           return results;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  Future<Map<String, dynamic>?> fetchGameDetails(String gameId) async {
    if (_detailsCache.containsKey(gameId)) {
      return _detailsCache[gameId];
    }

    final uri = Uri.parse('https://boardgamegeek.com/boardgame/$gameId');

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final html = response.body;
        final regex = RegExp(r'GEEK\.geekitemPreload\s*=\s*(\{.*?\});', dotAll: true);
        final match = regex.firstMatch(html);

        if (match != null) {
          final jsonString = match.group(1);
          if (jsonString != null) {
             try {
               final data = jsonDecode(jsonString);
               if (data is Map<String, dynamic>) {
                 _detailsCache[gameId] = data;
                 return data;
               }
             } catch (e) {
               print('DEBUG: JSON Decode Error: $e');
             }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  BoardGame? convertDetailsToLocal(Map<String, dynamic> details) {
      try {
        final item = details['item'];
        if (item == null) return null;

        final isExpansion = item['subtype'] == 'boardgameexpansion';
        String? parentGameId;

        if (isExpansion && item['links'] != null) {
          final expands = item['links']['expandsboardgame'];
          if (expands is List && expands.isNotEmpty) {
            parentGameId = expands[0]['objectid']?.toString();
          }
        }

        final id = item['id']?.toString() ?? '';
        final name = item['name'] ?? 'Unknown';
        final description = item['description'];
        final year = int.tryParse(item['yearpublished']?.toString() ?? '');
        final minPlayers = int.tryParse(item['minplayers']?.toString() ?? '');
        final maxPlayers = int.tryParse(item['maxplayers']?.toString() ?? '');
        final minPlayTime = int.tryParse(item['minplaytime']?.toString() ?? '');
        final maxPlayTime = int.tryParse(item['maxplaytime']?.toString() ?? '');
        final minAge = int.tryParse(item['minage']?.toString() ?? '');
        
        final stats = item['stats'];
        final avgRating = stats != null ? double.tryParse(stats['average']?.toString() ?? '') : null;
        
        final polls = item['polls'];
        final weight = polls != null && polls['boardgameweight'] != null 
            ? double.tryParse(polls['boardgameweight']['averageweight']?.toString() ?? '') 
            : null;

        final images = item['images'];
        final largeImage = images?['original']?.toString() ?? images?['large']?.toString();
        final thumbImage = images?['square']?.toString() ?? images?['thumb']?.toString();

        return BoardGame(
            id: id,
            name: name,
            description: description,
            yearPublished: year,
            minPlayers: minPlayers,
            maxPlayers: maxPlayers,
            playingTime: maxPlayTime,
            minPlayTime: minPlayTime,
            maxPlayTime: maxPlayTime,
            minAge: minAge,
            averageRating: avgRating,
            averageWeight: weight,
            customImageUrl: largeImage,
            customThumbnailUrl: thumbImage,
            dateAdded: DateTime.now(),
            isExpansion: isExpansion,
            parentGameId: parentGameId,
        );

      } catch (e) {
          return null;
      }
  }

  BoardGame convertToLocal({
    required Map<String, dynamic> searchResult,
    String? imageUrl,
    String? thumbnailUrl,
  }) {
    return BoardGame(
      id: searchResult['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: searchResult['localizedname'] ?? searchResult['name'] ?? 'Unknown',
      isExpansion: searchResult['subtype'] == 'boardgameexpansion',
      description: null,
      yearPublished: searchResult['yearpublished'] is int ? searchResult['yearpublished'] : int.tryParse(searchResult['yearpublished']?.toString() ?? ''),
      minPlayers: null,
      maxPlayers: null,
      playingTime: null,
      minPlayTime: null,
      maxPlayTime: null,
      minAge: null,
      averageRating: null,
      averageWeight: null,
      customImageUrl: imageUrl, 
      customThumbnailUrl: thumbnailUrl,
      dateAdded: DateTime.now(),
    );
  }

  Future<void> resetData() async {
    // 1. Clear in-memory state
    _ownedGames = [];
    _players = [];
    _playRecords = [];
    _userStats = UserStats();
    
    // 2. Overwrite local files with empty state
    // We don't just delete them because we want to sync the empty state
    try {
      final gamesFile = await _localFile;
      await gamesFile.writeAsString(jsonEncode([]));
      
      final playersFile = await _playersFile;
      await playersFile.writeAsString(jsonEncode([]));
      
      final playsFile = await _playsFile;
      await playsFile.writeAsString(jsonEncode([]));
      
      final statsFile = await _statsFile;
      await statsFile.writeAsString(jsonEncode(_userStats.toJson()));
      
      // 3. Increment version and sync to server
      // This will ensure remote also gets the empty files
      await _postSaveSync();
      
      notifyListeners();
    } catch (e) {
      print('DEBUG: Error resetting data: $e');
      rethrow;
    }
  }

  /// Initialize userId if not set
  Future<void> ensureUserId() async {
    if (_userStats.userId.isEmpty) {
      const uuid = Uuid();
      final newUserId = uuid.v4();
      _userStats = _userStats.copyWith(userId: newUserId);
      await saveUserStats();
    }
  }

  /// Generate default display name if not set
  String getDefaultDisplayName() {
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'Player$random';
  }

  /// Update display name
  Future<void> updateDisplayName(String name) async {
    _userStats = _userStats.copyWith(displayName: name);
    await saveUserStats();
    notifyListeners();
  }

  /// Check if leaderboard is enabled
  Future<bool> isLeaderboardEnabled() async {
    return await _syncService.isLeaderboardEnabled();
  }

  /// Upload current user's leaderboard entry
  Future<void> uploadLeaderboardEntry() async {
    await ensureUserId();
    
    // If display name is empty, set a default
    if (_userStats.displayName.isEmpty) {
      _userStats = _userStats.copyWith(displayName: getDefaultDisplayName());
      await saveUserStats();
    }

    // Calculate unique games played
    final uniqueGames = _playRecords.map((p) => p.gameId).toSet().length;
    
    // Calculate longest streak (from play history)
    int longestStreak = _calculateLongestStreak();

    final entry = LeaderboardEntry(
      userId: _userStats.userId,
      displayName: _userStats.displayName,
      customTitle: _userStats.customTitle,
      customBackgroundTier: _userStats.customBackgroundTier,
      lastUpdated: DateTime.now(),
      stats: LeaderboardStats(
        level: _userStats.level,
        totalXp: _userStats.totalAccumulatedXp, // Use total accumulated XP
        totalPlays: _userStats.totalPlays,
        uniqueGamesPlayed: uniqueGames,
        gamesOwned: _ownedGames.where((g) => g.status == GameStatus.owned || g.status == GameStatus.lended).length,
        achievementsUnlocked: _userStats.unlockedAchievementIds.length,
        currentStreak: _userStats.consecutiveDays,
        longestStreak: longestStreak,
      ),
    );

    await _syncService.uploadLeaderboardEntry(entry);
  }

  /// Calculate longest streak from play history
  int _calculateLongestStreak() {
    if (_playRecords.isEmpty) return 0;

    // Sort plays by date
    final sortedPlays = List<PlayRecord>.from(_playRecords)
      ..sort((a, b) => a.date.compareTo(b.date));

    int maxStreak = 1;
    int currentStreak = 1;
    DateTime? lastDate;

    for (final play in sortedPlays) {
      final playDate = DateTime(play.date.year, play.date.month, play.date.day);
      
      if (lastDate != null) {
        final diff = playDate.difference(lastDate).inDays;
        if (diff == 1) {
          currentStreak++;
          maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
        } else if (diff > 1) {
          currentStreak = 1;
        }
      }
      
      lastDate = playDate;
    }

    return maxStreak;
  }

  /// Download leaderboard
  Future<List<LeaderboardEntry>> downloadLeaderboard() async {
    return await _syncService.downloadLeaderboard();
  }

  /// Get the simplest game (lowest weight) in owned collection
  BoardGame? getSimplestGame() {
    final ownedWithWeight = _ownedGames
        .where((g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
                      g.averageWeight != null && 
                      g.averageWeight! > 0)
        .toList();
    
    if (ownedWithWeight.isEmpty) return null;
    
    ownedWithWeight.sort((a, b) => a.averageWeight!.compareTo(b.averageWeight!));
    return ownedWithWeight.first;
  }

  /// Get the hardest game (highest weight) in owned collection
  BoardGame? getHardestGame() {
    final ownedWithWeight = _ownedGames
        .where((g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
                      g.averageWeight != null && 
                      g.averageWeight! > 0)
        .toList();
    
    if (ownedWithWeight.isEmpty) return null;
    
    ownedWithWeight.sort((a, b) => b.averageWeight!.compareTo(a.averageWeight!));
    return ownedWithWeight.first;
  }

  /// Get the lowest rated game in owned collection
  BoardGame? getLowestRatedGame() {
    final ownedWithRating = _ownedGames
        .where((g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
                      g.averageRating != null && 
                      g.averageRating! > 0)
        .toList();
    
    if (ownedWithRating.isEmpty) return null;
    
    ownedWithRating.sort((a, b) => a.averageRating!.compareTo(b.averageRating!));
    return ownedWithRating.first;
  }

  /// Get the highest rated game in owned collection
  BoardGame? getHighestRatedGame() {
    final ownedWithRating = _ownedGames
        .where((g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
                      g.averageRating != null && 
                      g.averageRating! > 0)
        .toList();
    
    if (ownedWithRating.isEmpty) return null;
    
    ownedWithRating.sort((a, b) => b.averageRating!.compareTo(a.averageRating!));
    return ownedWithRating.first;
  }

  /// Get a solo-only game from owned collection
  BoardGame? getSoloOnlyGame() {
    return _ownedGames.firstWhere(
      (g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
             g.minPlayers == 1 && 
             g.maxPlayers == 1,
      orElse: () => BoardGame(id: '', name: '', dateAdded: DateTime.now()),
    ).id.isEmpty ? null : _ownedGames.firstWhere(
      (g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
             g.minPlayers == 1 && 
             g.maxPlayers == 1,
    );
  }

  /// Get a 2-player only game from owned collection
  BoardGame? getDuoOnlyGame() {
    return _ownedGames.firstWhere(
      (g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
             g.minPlayers == 2 && 
             g.maxPlayers == 2,
      orElse: () => BoardGame(id: '', name: '', dateAdded: DateTime.now()),
    ).id.isEmpty ? null : _ownedGames.firstWhere(
      (g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
             g.minPlayers == 2 && 
             g.maxPlayers == 2,
    );
  }

  /// Get a party game (8+ players) from owned collection
  BoardGame? getPartyGame() {
    return _ownedGames.firstWhere(
      (g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
             g.maxPlayers != null && 
             g.maxPlayers! >= 8,
      orElse: () => BoardGame(id: '', name: '', dateAdded: DateTime.now()),
    ).id.isEmpty ? null : _ownedGames.firstWhere(
      (g) => (g.status == GameStatus.owned || g.status == GameStatus.lended) && 
             g.maxPlayers != null && 
             g.maxPlayers! >= 8,
    );
  }

  /// Check if user has won N games in a row
  bool _checkWinningStreak(int streakLength) {
    if (_playRecords.length < streakLength) return false;
    
    // Sort plays by date
    final sortedPlays = List<PlayRecord>.from(_playRecords)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    int currentStreak = 0;
    String? currentUserId; // We don't track this, so check if ANY player won consecutively
    
    for (final play in sortedPlays) {
      if (play.winnerId != null) {
        if (currentUserId == null || currentUserId == play.winnerId) {
          currentUserId = play.winnerId;
          currentStreak++;
          if (currentStreak >= streakLength) return true;
        } else {
          currentUserId = play.winnerId;
          currentStreak = 1;
        }
      } else {
        currentStreak = 0;
        currentUserId = null;
      }
    }
    
    return false;
  }

  /// Check if user won by exactly 1 point
  bool _checkCloseCall() {
    for (final play in _playRecords) {
      if (play.winnerId == null || play.playerScores.isEmpty) continue;
      
      final scores = play.playerScores.values.where((s) => s != null).map((s) => s!).toList();
      if (scores.length < 2) continue;
      
      scores.sort((a, b) => b.compareTo(a)); // Sort descending
      final winningScore = scores[0];
      final secondScore = scores[1];
      
      if (winningScore - secondScore == 1) return true;
    }
    
    return false;
  }

  /// Check if user played 10+ games with the same 3+ players
  bool _checkRegularCrew() {
    // Group plays by player set
    final crewCounts = <String, int>{};
    
    for (final play in _playRecords) {
      if (play.playerScores.length < 3) continue;
      
      // Create a unique key for this player combination
      final playerIds = play.playerScores.keys.toList()..sort();
      final crewKey = playerIds.join(',');
      
      crewCounts[crewKey] = (crewCounts[crewKey] ?? 0) + 1;
    }
    
    return crewCounts.values.any((count) => count >= 10);
  }

  /// Check if user owns a complete set (base + all expansions)
  bool _checkCompleteSet() {
    // Get all base games that have expansions
    final baseGamesWithExpansions = <String>{};
    for (final game in _ownedGames) {
      if (game.isExpansion && 
          game.status == GameStatus.owned && 
          game.parentGameId != null) {
        baseGamesWithExpansions.add(game.parentGameId!);
      }
    }
    
    // Check if we own any of these base games
    for (final baseGameId in baseGamesWithExpansions) {
      final baseGame = _ownedGames.firstWhere(
        (g) => g.id == baseGameId && (g.status == GameStatus.owned || g.status == GameStatus.lended),
        orElse: () => BoardGame(id: '', name: '', dateAdded: DateTime.now()),
      );
      
      if (baseGame.id.isNotEmpty) {
        // We own this base game, so we have at least one complete set
        // (We can't verify if ALL expansions are owned without BGG API data)
        return true;
      }
    }
    
    return false;
  }

  /// Check if user played 5+ games in a single weekend (Saturday-Sunday)
  bool _checkWeekendWarrior() {
    // Group plays by weekend
    final weekendCounts = <String, int>{};
    
    for (final play in _playRecords) {
      final date = play.date;
      
      // Find the Saturday of this week
      DateTime saturday;
      if (date.weekday == DateTime.saturday) {
        saturday = DateTime(date.year, date.month, date.day);
      } else if (date.weekday == DateTime.sunday) {
        saturday = DateTime(date.year, date.month, date.day - 1);
      } else {
        continue; // Not a weekend play
      }
      
      final weekendKey = '${saturday.year}-${saturday.month}-${saturday.day}';
      weekendCounts[weekendKey] = (weekendCounts[weekendKey] ?? 0) + 1;
    }
    
    return weekendCounts.values.any((count) => count >= 5);
  }
}
