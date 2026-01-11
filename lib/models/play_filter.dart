import 'package:flutter/material.dart';

class PlayFilter {
  final String? gameId;
  final String? winnerId;
  final List<String> playerIds;
  final DateTimeRange? dateRange;

  PlayFilter({
    this.gameId,
    this.winnerId,
    this.playerIds = const [],
    this.dateRange,
  });

  bool get isEmpty =>
      gameId == null &&
      winnerId == null &&
      playerIds.isEmpty &&
      dateRange == null;

  PlayFilter copyWith({
    String? Function()? gameId,
    String? Function()? winnerId,
    List<String>? playerIds,
    DateTimeRange? Function()? dateRange,
  }) {
    return PlayFilter(
      gameId: gameId != null ? gameId() : this.gameId,
      winnerId: winnerId != null ? winnerId() : this.winnerId,
      playerIds: playerIds ?? this.playerIds,
      dateRange: dateRange != null ? dateRange() : this.dateRange,
    );
  }

  PlayFilter clear() => PlayFilter();
}
