class PlayRecord {
  final String id;
  final String gameId;
  final String gameName;
  final String? gameThumbnailUrl;
  final DateTime date;
  final int? durationMinutes;
  final Map<String, int?> playerScores; // Map<PlayerId, Score>
  final String? winnerId;
  final List<String> expansionIds;

  PlayRecord({
    required this.id,
    required this.gameId,
    required this.gameName,
    this.gameThumbnailUrl,
    required this.date,
    this.durationMinutes,
    required this.playerScores,
    this.winnerId,
    this.expansionIds = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameId': gameId,
      'gameName': gameName,
      'gameThumbnailUrl': gameThumbnailUrl,
      'date': date.toIso8601String(),
      'durationMinutes': durationMinutes,
      'playerScores': playerScores,
      'winnerId': winnerId,
      'expansionIds': expansionIds,
    };
  }

  factory PlayRecord.fromJson(Map<String, dynamic> json) {
    return PlayRecord(
      id: json['id'],
      gameId: json['gameId'],
      gameName: json['gameName'],
      gameThumbnailUrl: json['gameThumbnailUrl'],
      date: DateTime.parse(json['date']),
      durationMinutes: json['durationMinutes'],
      playerScores: Map<String, int?>.from(json['playerScores'] ?? {}),
      winnerId: json['winnerId'],
      expansionIds: List<String>.from(json['expansionIds'] ?? []),
    );
  }
}
