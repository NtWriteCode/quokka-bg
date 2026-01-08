import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

class SyncService {
  static const _storage = FlutterSecureStorage();
  static const _folderName = 'bg-tracker';
  static const _metadataFile = 'metadata.json';

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

      final remotePath = _folderName; // webdav client handles paths relative to base URL usually?
      // Actually webdav_client usually treats paths as absolute if they start with /. 
      // If we provided a base URL like https://dav.com/remote.php/webdav/, 
      // operations usually append to it. 
      // Let's use relative paths or ensure we handle it correctly.
      // The library usually expects paths to NOT start with / if they are relative to the Base URL.
      
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
}
