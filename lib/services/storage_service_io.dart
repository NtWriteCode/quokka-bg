
import 'dart:io';
import 'package:bg_tracker/services/storage_service.dart';
import 'package:path_provider/path_provider.dart';

class FileStorageService implements StorageService {
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/games.json');
  }

  @override
  Future<String?> readGamesJson() async {
    try {
        final file = await _localFile;
        if (!await file.exists()) return null;
        return await file.readAsString();
    } catch (_) {
        return null;
    }
  }

  @override
  Future<void> writeGamesJson(String json) async {
    final file = await _localFile;
    await file.writeAsString(json);
  }
}

StorageService createStorage() => FileStorageService();
