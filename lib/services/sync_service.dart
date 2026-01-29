import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:quokka/models/leaderboard_entry.dart';
import 'package:quokka/models/user_stats.dart';
import 'package:quokka/models/sync_status.dart';

class SyncSummary {
  final String displayName;
  final int level;
  final int achievements;
  final int totalXp;
  final int games;
  final int plays;
  final int players;
  final bool hasData;

  const SyncSummary({
    required this.displayName,
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

  // Retry configuration
  static const _maxRetries = 3;
  static const _retryDelayMs = [500, 1000, 2000]; // Exponential backoff

  /// Log a debug message (only in debug mode)
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SyncService] $message');
    }
  }

  /// Execute an operation with retry logic
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    String operationName = 'operation',
    int maxRetries = _maxRetries,
  }) async {
    Exception? lastError;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } on SocketException catch (e) {
        lastError = e;
        _log('$operationName failed (attempt ${attempt + 1}/$maxRetries): Network error - ${e.message}');
      } on HttpException catch (e) {
        lastError = e;
        _log('$operationName failed (attempt ${attempt + 1}/$maxRetries): HTTP error - ${e.message}');
      } catch (e) {
        // Don't retry non-network errors
        _log('$operationName failed (non-retryable): $e');
        rethrow;
      }
      
      if (attempt < maxRetries - 1) {
        final delay = _retryDelayMs[attempt];
        _log('Retrying $operationName in ${delay}ms...');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    
    throw lastError ?? Exception('$operationName failed after $maxRetries retries');
  }

  Future<void> saveCredentials({
    required String url,
    required String user,
    required String pass,
  }) async {
    // Ensure URL ends with slash for consistency
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
      if (logErrors) _log('Missing credentials for WebDAV connection');
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
      if (logErrors) _log('WebDAV Client creation failed: $e');
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
    String displayName = '';

    Future<List<dynamic>?> readList(String fileName) async {
      try {
        final content = await _withRetry(
          () => client.read('$_folderName/$fileName'),
          operationName: 'read $fileName',
        );
        final json = jsonDecode(utf8.decode(content));
        if (json is List) {
          hasAny = true;
          return json;
        }
      } on FormatException catch (e) {
        _log('JSON parse error for $fileName: $e');
      } catch (e) {
        // File might not exist, which is expected for new users
        _log('Could not read $fileName: $e');
      }
      return null;
    }

    try {
      final statsContent = await _withRetry(
        () => client.read('$_folderName/user_stats.json'),
        operationName: 'read user_stats',
      );
      final json = jsonDecode(utf8.decode(statsContent));
      if (json is Map<String, dynamic>) {
        final stats = UserStats.fromJson(json);
        level = stats.level;
        totalXp = stats.totalXp.round();
        achievements = stats.unlockedAchievementIds.length;
        displayName = stats.displayName;
        hasAny = true;
      }
    } catch (e) {
      _log('Could not read user_stats.json: $e');
    }

    final gamesList = await readList('games.json');
    if (gamesList != null) games = gamesList.length;
    final playsList = await readList('plays.json');
    if (playsList != null) plays = playsList.length;
    final playersList = await readList('players.json');
    if (playersList != null) players = playersList.length;

    return SyncSummary(
      displayName: displayName,
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
      await _withRetry(
        () => client.ping(),
        operationName: 'ping',
      );
      return null; // Success
    } catch (e) {
      _log('WebDAV Ping failed: $e');
      return e.toString();
    }
  }

  /// Sync with the server. Returns a SyncLogEntry with detailed results.
  Future<SyncLogEntry> sync(
    Directory localDir,
    int localVersion, {
    bool allowUpload = false,
    SyncTrigger trigger = SyncTrigger.autoCheck,
  }) async {
    final builder = SyncLogBuilder(
      direction: SyncDirection.download,
      trigger: trigger,
      localVersionBefore: localVersion,
    );

    final client = await _connect();
    if (client == null) {
      return builder.build(SyncResultType.noCredentials);
    }

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
        final List<int> content = await _withRetry(
          () => client.read('$_folderName/$_metadataFile'),
          operationName: 'read metadata',
        );
        final json = jsonDecode(utf8.decode(content));
        remoteVersion = json['version'] ?? 0;
        builder.remoteVersion = remoteVersion;
      } catch (e) {
        // Metadata doesn't exist or is invalid
        _log('Metadata read failed (might not exist yet): $e');
        remoteVersion = 0;
      }

      if (remoteVersion > localVersion) {
        // Download all JSONs INCLUDING metadata.json to keep versions in sync
        final files = ['games.json', 'players.json', 'plays.json', 'user_stats.json', 'metadata.json'];
        for (final fileName in files) {
          try {
            final content = await _withRetry(
              () => client.read('$_folderName/$fileName'),
              operationName: 'download $fileName',
            );
            final localFile = File(p.join(localDir.path, fileName));
            await localFile.writeAsBytes(content);
            builder.addSuccess(fileName);
          } catch (e) {
            builder.addFailure(fileName);
            builder.addWarning('Failed to download $fileName: $e');
            _log('Failed to download $fileName: $e');
          }
        }

        builder.localVersionAfter = remoteVersion;

        if (builder.failedFiles.length == files.length) {
          builder.addError('All file downloads failed');
          return builder.build(SyncResultType.failure);
        }

        if (builder.failedFiles.isNotEmpty) {
          return builder.build(SyncResultType.partial);
        }

        return builder.build(SyncResultType.success);
      } else if (localVersion > remoteVersion && allowUpload) {
        // Upload local files
        return await upload(localDir, localVersion, trigger: trigger);
      }

      // Versions match, nothing to do
      builder.localVersionAfter = localVersion;
      return builder.build(SyncResultType.skipped);
    } catch (e) {
      _log('Sync failed: $e');
      builder.addError('Sync failed: $e');
      return builder.build(SyncResultType.failure);
    }
  }

  Future<int?> fetchRemoteVersion({String? url, String? user, String? pass}) async {
    final client = await _connect(url: url, user: user, pass: pass, logErrors: false);
    if (client == null) return null;

    try {
      final List<int> content = await _withRetry(
        () => client.read('$_folderName/$_metadataFile'),
        operationName: 'fetch remote version',
      );
      final json = jsonDecode(utf8.decode(content));
      return json['version'] ?? 0;
    } catch (e) {
      _log('Could not fetch remote version: $e');
      return null;
    }
  }

  Future<SyncLogEntry> upload(
    Directory localDir,
    int version, {
    SyncTrigger trigger = SyncTrigger.autoSave,
  }) async {
    final builder = SyncLogBuilder(
      direction: SyncDirection.upload,
      trigger: trigger,
      localVersionBefore: version,
    );

    final client = await _connect();
    if (client == null) {
      return builder.build(SyncResultType.noCredentials);
    }

    try {
      // Ensure folder exists
      try { await client.mkdir(_folderName); } catch (_) {}

      final files = ['games.json', 'players.json', 'plays.json', 'user_stats.json'];
      for (final fileName in files) {
        final localFile = File(p.join(localDir.path, fileName));
        if (await localFile.exists()) {
          try {
            final bytes = await localFile.readAsBytes();
            await _withRetry(
              () => client.write('$_folderName/$fileName', bytes),
              operationName: 'upload $fileName',
            );
            builder.addSuccess(fileName);
          } catch (e) {
            builder.addFailure(fileName);
            builder.addWarning('Failed to upload $fileName: $e');
            _log('Failed to upload $fileName: $e');
          }
        }
      }

      // Update metadata only if at least some files were uploaded
      if (builder.successfulFiles.isNotEmpty) {
        try {
          final meta = jsonEncode({'version': version, 'timestamp': DateTime.now().toIso8601String()});
          await _withRetry(
            () => client.write('$_folderName/$_metadataFile', utf8.encode(meta)),
            operationName: 'upload metadata',
          );
          builder.addSuccess('metadata.json');
        } catch (e) {
          builder.addWarning('Failed to update metadata: $e');
          _log('Failed to update metadata: $e');
        }
      }

      builder.localVersionAfter = version;

      if (builder.failedFiles.length == files.length) {
        builder.addError('All file uploads failed');
        return builder.build(SyncResultType.failure);
      }

      if (builder.failedFiles.isNotEmpty) {
        return builder.build(SyncResultType.partial);
      }

      return builder.build(SyncResultType.success);
    } catch (e) {
      _log('Upload failed: $e');
      builder.addError('Upload failed: $e');
      return builder.build(SyncResultType.failure);
    }
  }

  /// Check if leaderboard feature is enabled on the server
  Future<bool> isLeaderboardEnabled() async {
    final client = await _connect(logErrors: false);
    if (client == null) return false;

    try {
      // Check if global_shared folder exists (this indicates feature is enabled)
      await _withRetry(
        () => client.readDir('global_shared'),
        operationName: 'check leaderboard folder',
        maxRetries: 1, // Don't retry much for feature detection
      );
      
      // If it exists, ensure our subfolders are created
      try { await client.mkdir(_globalSharedFolder); } catch (_) {}
      try { await client.mkdir(_leaderboardFolder); } catch (_) {}
      
      return true;
    } catch (e) {
      _log('Leaderboard not enabled or not accessible: $e');
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
      await _withRetry(
        () => client.write('$_leaderboardFolder/$fileName', utf8.encode(json)),
        operationName: 'upload leaderboard entry',
      );
    } catch (e) {
      _log('Leaderboard upload failed: $e');
    }
  }

  /// Download all leaderboard entries
  Future<List<LeaderboardEntry>> downloadLeaderboard() async {
    final client = await _connect();
    if (client == null) return [];

    try {
      final files = await _withRetry(
        () => client.readDir(_leaderboardFolder),
        operationName: 'list leaderboard',
      );
      final entries = <LeaderboardEntry>[];

      for (final file in files) {
        if (file.name?.endsWith('.json') ?? false) {
          try {
            final content = await _withRetry(
              () => client.read('$_leaderboardFolder/${file.name}'),
              operationName: 'read leaderboard entry ${file.name}',
              maxRetries: 2,
            );
            final json = jsonDecode(utf8.decode(content));
            entries.add(LeaderboardEntry.fromJson(json));
          } catch (e) {
            _log('Failed to parse leaderboard entry ${file.name}: $e');
          }
        }
      }

      return entries;
    } catch (e) {
      _log('Leaderboard download failed: $e');
      return [];
    }
  }
}
