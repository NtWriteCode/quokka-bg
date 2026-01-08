
abstract class StorageService {
  Future<String?> readGamesJson();
  Future<void> writeGamesJson(String json);
}
