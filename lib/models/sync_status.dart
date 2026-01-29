import 'dart:convert';

/// Represents the type of sync operation
enum SyncDirection {
  upload,
  download,
  bidirectional, // When we check and potentially do both
}

/// Represents the result of a sync operation
enum SyncResultType {
  success,
  partial,
  failure,
  noCredentials,
  skipped, // When no sync was needed (versions match)
}

/// What triggered the sync
enum SyncTrigger {
  appStart,      // Initial load (download check)
  manualUpload,  // User pressed force upload
  manualDownload,// User pressed force download  
  autoSync,      // Automatic batched upload after changes
}

/// A single sync log entry for history
class SyncLogEntry {
  final String id;
  final DateTime timestamp;
  final SyncDirection direction;
  final SyncResultType resultType;
  final SyncTrigger trigger;
  final int filesUploaded;
  final int filesDownloaded;
  final int filesFailed;
  final List<String> successfulFiles;
  final List<String> failedFiles;
  final List<String> warnings;
  final List<String> errors;
  final int? localVersionBefore;
  final int? localVersionAfter;
  final int? remoteVersion;
  final int durationMs;

  const SyncLogEntry({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.resultType,
    required this.trigger,
    this.filesUploaded = 0,
    this.filesDownloaded = 0,
    this.filesFailed = 0,
    this.successfulFiles = const [],
    this.failedFiles = const [],
    this.warnings = const [],
    this.errors = const [],
    this.localVersionBefore,
    this.localVersionAfter,
    this.remoteVersion,
    this.durationMs = 0,
  });

  bool get isSuccess => resultType == SyncResultType.success;
  bool get isPartial => resultType == SyncResultType.partial;
  bool get isFailure => resultType == SyncResultType.failure;
  bool get hasIssues => warnings.isNotEmpty || errors.isNotEmpty;
  
  int get totalFilesAffected => filesUploaded + filesDownloaded;

  String get directionLabel {
    switch (direction) {
      case SyncDirection.upload:
        return 'Upload';
      case SyncDirection.download:
        return 'Download';
      case SyncDirection.bidirectional:
        return 'Sync';
    }
  }

  String get triggerLabel {
    switch (trigger) {
      case SyncTrigger.appStart:
        return 'App Start';
      case SyncTrigger.manualUpload:
        return 'Manual Upload';
      case SyncTrigger.manualDownload:
        return 'Manual Download';
      case SyncTrigger.autoSync:
        return 'Auto Sync';
    }
  }

  String get resultLabel {
    switch (resultType) {
      case SyncResultType.success:
        return 'Success';
      case SyncResultType.partial:
        return 'Partial';
      case SyncResultType.failure:
        return 'Failed';
      case SyncResultType.noCredentials:
        return 'No Credentials';
      case SyncResultType.skipped:
        return 'Skipped';
    }
  }

  String get summary {
    if (resultType == SyncResultType.noCredentials) {
      return 'No sync credentials configured';
    }
    if (resultType == SyncResultType.skipped) {
      return 'Already up to date';
    }
    
    final parts = <String>[];
    if (filesUploaded > 0) parts.add('↑$filesUploaded');
    if (filesDownloaded > 0) parts.add('↓$filesDownloaded');
    if (filesFailed > 0) parts.add('✗$filesFailed');
    
    if (parts.isEmpty) {
      return resultLabel;
    }
    return '${parts.join(' ')} • $resultLabel';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'direction': direction.index,
    'resultType': resultType.index,
    'trigger': trigger.index,
    'filesUploaded': filesUploaded,
    'filesDownloaded': filesDownloaded,
    'filesFailed': filesFailed,
    'successfulFiles': successfulFiles,
    'failedFiles': failedFiles,
    'warnings': warnings,
    'errors': errors,
    'localVersionBefore': localVersionBefore,
    'localVersionAfter': localVersionAfter,
    'remoteVersion': remoteVersion,
    'durationMs': durationMs,
  };

  factory SyncLogEntry.fromJson(Map<String, dynamic> json) => SyncLogEntry(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: DateTime.parse(json['timestamp']),
    direction: SyncDirection.values[json['direction'] ?? 0],
    resultType: SyncResultType.values[json['resultType'] ?? 0],
    trigger: SyncTrigger.values[json['trigger'] ?? 0],
    filesUploaded: json['filesUploaded'] ?? 0,
    filesDownloaded: json['filesDownloaded'] ?? 0,
    filesFailed: json['filesFailed'] ?? 0,
    successfulFiles: List<String>.from(json['successfulFiles'] ?? []),
    failedFiles: List<String>.from(json['failedFiles'] ?? []),
    warnings: List<String>.from(json['warnings'] ?? []),
    errors: List<String>.from(json['errors'] ?? []),
    localVersionBefore: json['localVersionBefore'],
    localVersionAfter: json['localVersionAfter'],
    remoteVersion: json['remoteVersion'],
    durationMs: json['durationMs'] ?? 0,
  );
}

/// Builder for creating sync log entries
class SyncLogBuilder {
  final DateTime _startTime = DateTime.now();
  final SyncDirection direction;
  final SyncTrigger trigger;
  int? localVersionBefore;
  int? localVersionAfter;
  int? remoteVersion;
  
  final List<String> successfulFiles = [];
  final List<String> failedFiles = [];
  final List<String> warnings = [];
  final List<String> errors = [];

  SyncLogBuilder({
    required this.direction,
    required this.trigger,
    this.localVersionBefore,
  });

  void addSuccess(String fileName) => successfulFiles.add(fileName);
  void addFailure(String fileName) => failedFiles.add(fileName);
  void addWarning(String message) => warnings.add(message);
  void addError(String message) => errors.add(message);

  SyncLogEntry build(SyncResultType resultType) {
    final endTime = DateTime.now();
    return SyncLogEntry(
      id: _startTime.millisecondsSinceEpoch.toString(),
      timestamp: _startTime,
      direction: direction,
      resultType: resultType,
      trigger: trigger,
      filesUploaded: direction == SyncDirection.upload || direction == SyncDirection.bidirectional
          ? successfulFiles.length
          : 0,
      filesDownloaded: direction == SyncDirection.download || direction == SyncDirection.bidirectional
          ? successfulFiles.length
          : 0,
      filesFailed: failedFiles.length,
      successfulFiles: List.unmodifiable(successfulFiles),
      failedFiles: List.unmodifiable(failedFiles),
      warnings: List.unmodifiable(warnings),
      errors: List.unmodifiable(errors),
      localVersionBefore: localVersionBefore,
      localVersionAfter: localVersionAfter,
      remoteVersion: remoteVersion,
      durationMs: endTime.difference(_startTime).inMilliseconds,
    );
  }
}

/// Manages sync history persistence
class SyncHistoryManager {
  static const _maxEntries = 50;
  
  List<SyncLogEntry> _entries = [];
  
  List<SyncLogEntry> get entries => List.unmodifiable(_entries);
  
  SyncLogEntry? get lastEntry => _entries.isNotEmpty ? _entries.first : null;
  
  /// Get entries filtered by result type
  List<SyncLogEntry> getByResult(SyncResultType type) =>
      _entries.where((e) => e.resultType == type).toList();
  
  /// Get entries from the last N hours
  List<SyncLogEntry> getRecent(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _entries.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  /// Add a new entry and trim old ones
  void addEntry(SyncLogEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
  }

  /// Clear all history
  void clear() => _entries.clear();

  /// Load from JSON string (from SharedPreferences)
  void loadFromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      _entries = [];
      return;
    }
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      _entries = list.map((e) => SyncLogEntry.fromJson(e)).toList();
    } catch (e) {
      _entries = [];
    }
  }

  /// Save to JSON string (for SharedPreferences)
  String toJson() => jsonEncode(_entries.map((e) => e.toJson()).toList());

  /// Get statistics
  Map<String, dynamic> getStats() {
    final last24h = getRecent(const Duration(hours: 24));
    final successCount = last24h.where((e) => e.isSuccess).length;
    final skippedCount = last24h.where((e) => e.resultType == SyncResultType.skipped).length;
    final partialCount = last24h.where((e) => e.isPartial).length;
    final failureCount = last24h.where((e) => e.isFailure).length;
    
    // Calculate success rate: (success + skipped) / total
    // Both success and skipped mean sync is working correctly
    final healthyCount = successCount + skippedCount;
    
    return {
      'total': _entries.length,
      'last24h': last24h.length,
      'successRate': last24h.isNotEmpty 
          ? (healthyCount / last24h.length * 100).round()
          : 100,
      'successCount': successCount,
      'skippedCount': skippedCount,
      'partialCount': partialCount,
      'failureCount': failureCount,
    };
  }
}

/// Simple async lock for serializing operations
class AsyncLock {
  Future<void>? _lock;

  Future<T> synchronized<T>(Future<T> Function() action) async {
    // Wait for any existing lock
    while (_lock != null) {
      try {
        await _lock;
      } catch (_) {
        // Ignore errors from previous operations
      }
    }

    // Create our lock
    final completer = Future<T>.sync(() async {
      try {
        return await action();
      } finally {
        _lock = null;
      }
    });

    _lock = completer.then((_) {}).catchError((_) {});
    return completer;
  }
}
