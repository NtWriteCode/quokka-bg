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
import 'package:quokka/services/sync_service.dart';
import 'package:quokka/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameRepository extends ChangeNotifier {
  List<BoardGame> _ownedGames = [];
  List<Player> _players = [];
  List<PlayRecord> _playRecords = [];
  
  UserStats _userStats = UserStats();
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
  
  Future<void> addXp(int amount, String reason) async {
    int newXp = _userStats.totalXp + amount;
    int newLevel = _userStats.level;
    
    while (newXp >= (99 + (newLevel + 1))) {
      newXp -= (99 + (newLevel + 1));
      newLevel++;
    }
    
    _userStats = _userStats.copyWith(
      totalXp: newXp,
      level: newLevel,
      xpHistory: [
        XpLogEntry(date: DateTime.now(), reason: reason, amount: amount),
        ..._userStats.xpHistory,
      ].take(50).toList(), // Keep last 50 entries
    );
    await saveUserStats();
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
        case 'wish_1': shouldUnlock = _ownedGames.any((g) => g.isWishlist); break;
        case 'wish_to_own_1': shouldUnlock = _userStats.wishlistConversions >= 1; break;
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
        await addXp(ach.xpReward, 'Achievement: ${ach.title}');
      }
      _unlockedController.add(newUnlocks);
      await saveUserStats();
    }
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
      notifyListeners();
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

  Future<void> triggerManualSyncUp() async {
    final directory = await getApplicationDocumentsDirectory();
    await _syncService.upload(directory, _dataVersion);
  }

  @override
  void dispose() {
    _unlockedController.close();
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
      await addXp(2, 'Added to Wishlist: ${game.name}');
    } else {
      await addXp(50, 'New Collection Entry: ${game.name}');
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
    int playerCount = record.playerScores.length;
    await addXp(2 * playerCount, 'Played ${record.gameName} with $playerCount people');
    
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
      await addXp(15, 'Got it! Wishlist -> Collection: ${oldGame.name}');
    } else if (newStatus == GameStatus.sold) {
      _userStats = _userStats.copyWith(soldCount: _userStats.soldCount + 1);
      await addXp(10, 'Sold: ${oldGame.name}');
    } else if (newStatus == GameStatus.lended) {
      _userStats = _userStats.copyWith(lendedCount: _userStats.lendedCount + 1);
      await addXp(10, 'Lent: ${oldGame.name}');
    }
    await checkAchievements();
  }

  Future<void> removeGame(String id) async {
    await _preSaveSync();
    _ownedGames.removeWhere((g) => g.id == id);
    await saveGames();
  }

  Future<List<Map<String, dynamic>>> searchBgg(String query) async {
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
           return List<Map<String, dynamic>>.from(data['items']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  Future<Map<String, dynamic>?> fetchGameDetails(String gameId) async {
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
               return jsonDecode(jsonString);
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
      name: searchResult['name'] ?? 'Unknown',
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
}
