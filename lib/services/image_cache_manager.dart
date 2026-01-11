import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class QuokkaCacheManager {
  static const String key = 'quokka_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
