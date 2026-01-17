import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:quokka/models/leaderboard_entry.dart';
import 'package:quokka/models/user_stats.dart';

class SyncSummary {
  final int level;
  final int achievements;
  final int totalXp;
  final int games;
  final int plays;
  final int players;
  final bool hasData;

  const SyncSummary({
    required this.level,
    required this.achievements,
    required this.totalXp,
    required this.games,
    required this.plays,
    required this.players,
    required this.hasData,
  });
}

class SyncService {
  static const _storage = FlutterSecureStorage();
  static const _folderName = 'bg-tracker';
  static const _metadataFile = 'metadata.json';
  static const _globalSharedFolder = 'global_shared/quokka_bg';
  static const _leaderboardFolder = 'global_shared/quokka_bg/leaderboard';

  static const _keyUrl = 'webdav_url';
  static const _keyUser = 'webdav_user';
  static const _keyPass = 'webdav_pass';

  Future<void> saveCredentials({
    required String url,
    required String user,
    required String pass,
  }) async {
    // Ensure URL ends with slash for consistency if not present, though client handles path joining
    // But for base URL it is safer to be clean.
    var cleanUrl = url.trim();
    if (!cleanUrl.endsWith('/')) cleanUrl += '/';
    
    await _storage.write(key: _keyUrl, value: cleanUrl);
    await _storage.write(key: _keyUser, value: user);
    await _storage.write(key: _keyPass, value: pass);
  }

  Future<Map<String, String?>> getCredentials() async {
    return {
      'url': await _storage.read(key: _keyUrl),
      'user': await _storage.read(key: _keyUser),
      'pass': await _storage.read(key: _keyPass),
    };
  }

  Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds['url'] != null && creds['user'] != null && creds['pass'] != null;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyUser);
    await _storage.delete(key: _keyPass);
  }

  Future<webdav.Client?> _connect({
    String? url,
    String? user,
    String? pass,
    bool logErrors = true,
  }) async {
    final creds = await getCredentials();
    final targetUrl = url ?? creds['url'];
    final targetUser = user ?? creds['user'];
    final targetPass = pass ?? creds['pass'];

    if (targetUrl == null || targetUser == null || targetPass == null) {
      return null;
    }

    try {
      final client = webdav.newClient(
        targetUrl,
        user: targetUser,
        password: targetPass,
        debug: false,
      );
      return client;
    } catch (e) {
      if (logErrors) print('DEBUG: WebDAV Client creation failed: $e');
      return null;
    }
  }

  Future<SyncSummary?> fetchRemoteSummary({String? url, String? user, String? pass}) async {
    final client = await _connect(url: url, user: user, pass: pass, logErrors: false);
    if (client == null) return null;

    bool hasAny = false;
    int games = 0;
    int plays = 0;
    int players = 0;
    int achievements = 0;
    int totalXp = 0;
    int level = 1;

    Future<List<dynamic>?> _readList(String fileName) async {
      try {
        final content = await client.read('$_folderName/$fileName');
        final json = jsonDecode(utf8.decode(content));
        if (json is List) {
          hasAny = true;
          return json;
        }
      } catch (_) {}
      return null;
    }

    try {
      final statsContent = await client.read('$_folderName/user_stats.json');
      final json = jsonDecode(utf8.decode(statsContent));
      if (json is Map<String, dynamic>) {
        final stats = UserStats.fromJson(json);
        level = stats.level;
        totalXp = stats.totalXp.round();
        achievements = stats.unlockedAchievementIds.length;
        hasAny = true;
      }
    } catch (_) {}

    final gamesList = await _readList('games.json');
    if (gamesList != null) games = gamesList.length;
    final playsList = await _readList('plays.json');
    if (playsList != null) plays = playsList.length;
    final playersList = await _readList('players.json');
    if (playersList != null) players = playersList.length;

    return SyncSummary(
      level: level,
      achievements: achievements,
      totalXp: totalXp,
      games: games,
      plays: plays,
      players: players,
      hasData: hasAny,
    );
  }

  Future<String?> testConnection({String? url, String? user, String? pass}) async {
    final client = await _connect(url: url, user: user, pass: pass);
    if (client == null) return 'Missing credentials or invalid URL format.';
    try {
      await client.ping();
      return null; // Success
    } catch (e) {
      print('DEBUG: WebDAV Ping failed: $e');
      return e.toString();
    }
  }

  /// Checks if remote version is newer than local.
  /// Returns [true] if remote is newer and files were downloaded.
  Future<bool> sync(Directory localDir, int localVersion) async {
    final client = await _connect();
    if (client == null) return false;

    try {
      // Ensure bg-tracker folder exists
      try {
        await client.mkdir(_folderName);
      } catch (e) {
        // Folder likely exists, ignore
      }
      
      // Check metadata
      int remoteVersion = 0;
      try {
        final List<int> content = await client.read('$_folderName/$_metadataFile');
        final json = jsonDecode(utf8.decode(content));
        remoteVersion = json['version'] ?? 0;
      } catch (e) {
        // Metadata doesn't exist or is invalid
        remoteVersion = 0;
      }

      if (remoteVersion > localVersion) {
        // Download all JSONs
        final files = ['games.json', 'players.json', 'plays.json', 'user_stats.json'];
        for (final fileName in files) {
          try {
            final content = await client.read('$_folderName/$fileName');
            final localFile = File(p.join(localDir.path, fileName));
            await localFile.writeAsBytes(content);
          } catch (e) {
            print('DEBUG: Failed to download $fileName: $e');
          }
        }
        return true;
      } else if (localVersion > remoteVersion) {
        // Upload local files
        await upload(localDir, localVersion);
      }
      
      return false;
    } catch (e) {
      print('DEBUG: Sync failed: $e');
      return false;
    }
  }

  Future<void> upload(Directory localDir, int version) async {
    final client = await _connect();
    if (client == null) return;

    try {
      // Ensure folder
      try { await client.mkdir(_folderName); } catch (_) {}

      final files = ['games.json', 'players.json', 'plays.json', 'user_stats.json'];
      for (final fileName in files) {
        final localFile = File(p.join(localDir.path, fileName));
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          await client.write('$_folderName/$fileName', bytes);
        }
      }

      // Update metadata
      final meta = jsonEncode({'version': version, 'timestamp': DateTime.now().toIso8601String()});
      await client.write('$_folderName/$_metadataFile', utf8.encode(meta));
      
    } catch (e) {
      print('DEBUG: Upload failed: $e');
    }
  }

  /// Check if leaderboard feature is enabled on the server
  /// Returns true if /global_shared exists (feature enabled server-side)
  Future<bool> isLeaderboardEnabled() async {
    final client = await _connect(logErrors: false);
    if (client == null) return false;

    try {
      // Check if global_shared folder exists (this indicates feature is enabled)
      await client.readDir('global_shared');
      
      // If it exists, ensure our subfolders are created
      try { await client.mkdir(_globalSharedFolder); } catch (_) {}
      try { await client.mkdir(_leaderboardFolder); } catch (_) {}
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload user's leaderboard entry
  Future<void> uploadLeaderboardEntry(LeaderboardEntry entry) async {
    final client = await _connect();
    if (client == null) return;

    try {
      // Folders should already be created by isLeaderboardEnabled check
      // But ensure they exist just in case
      try { await client.mkdir(_globalSharedFolder); } catch (_) {}
      try { await client.mkdir(_leaderboardFolder); } catch (_) {}

      final fileName = 'user_${entry.userId}.json';
      final json = jsonEncode(entry.toJson());
      await client.write('$_leaderboardFolder/$fileName', utf8.encode(json));
    } catch (e) {
      print('DEBUG: Leaderboard upload failed: $e');
    }
  }

  /// Download all leaderboard entries
  Future<List<LeaderboardEntry>> downloadLeaderboard() async {
    final client = await _connect();
    if (client == null) return [];

    try {
      final files = await client.readDir(_leaderboardFolder);
      final entries = <LeaderboardEntry>[];

      for (final file in files) {
        if (file.name?.endsWith('.json') ?? false) {
          try {
            final content = await client.read('$_leaderboardFolder/${file.name}');
            final json = jsonDecode(utf8.decode(content));
            entries.add(LeaderboardEntry.fromJson(json));
          } catch (e) {
            print('DEBUG: Failed to parse leaderboard entry ${file.name}: $e');
          }
        }
      }

      return entries;
    } catch (e) {
      print('DEBUG: Leaderboard download failed: $e');
      return [];
    }
  }
}
