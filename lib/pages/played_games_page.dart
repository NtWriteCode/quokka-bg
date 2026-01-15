import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quokka/models/play_record.dart';
import 'package:quokka/services/image_cache_manager.dart';
import 'package:quokka/pages/add_play_page.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/models/play_filter.dart';
import 'package:quokka/widgets/play_filter_sheet.dart';
import 'package:quokka/models/board_game.dart'; // For GameStatus

class PlayedGamesPage extends StatefulWidget {
  final GameRepository repository;

  const PlayedGamesPage({super.key, required this.repository});

  @override
  State<PlayedGamesPage> createState() => _PlayedGamesPageState();
}

class _PlayedGamesPageState extends State<PlayedGamesPage> {
  bool _isLoading = true;
  PlayFilter _currentFilter = PlayFilter();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    _loadPlays();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  Future<void> _loadPlays() async {
    await widget.repository.loadPlays();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var plays = List<PlayRecord>.from(widget.repository.playRecords)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Apply Filter
    if (!_currentFilter.isEmpty) {
      plays = plays.where((p) {
        // Game filter
        if (_currentFilter.gameId != null && p.gameId != _currentFilter.gameId) return false;
        
        // Winner filter
        if (_currentFilter.winnerId != null && p.winnerId != _currentFilter.winnerId) return false;
        
        // Participants filter (Subset matching - play must include ALL selected players)
        if (_currentFilter.playerIds.isNotEmpty) {
          final playPlayerIds = p.playerScores.keys.toSet();
          if (!_currentFilter.playerIds.every((id) => playPlayerIds.contains(id))) return false;
        }
        
        // Date range filter
        if (_currentFilter.dateRange != null) {
          final date = p.date;
          if (date.isBefore(_currentFilter.dateRange!.start) || date.isAfter(_currentFilter.dateRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        }
        
        return true;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Play History'),
        actions: [
          IconButton(
            icon: Icon(_currentFilter.isEmpty ? Icons.filter_list : Icons.filter_list_off),
            color: _currentFilter.isEmpty ? null : Colors.amber,
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPlayPage(repository: widget.repository)),
          );
          if (added == true) {
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (!_currentFilter.isEmpty) _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : plays.isEmpty
                    ? const Center(child: Text('No plays found matching filters.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: plays.length,
                  itemBuilder: (context, index) {
                    final play = plays[index];
                    String playersText = '';
                    if (play.playerScores.isNotEmpty) {
                      playersText = play.playerScores.keys.map((pid) {
                        final player = widget.repository.players.cast<dynamic>().firstWhere((p) => p.id == pid, orElse: () => null);
                        return player?.name ?? 'Unknown';
                      }).join(', ');
                    }

                    return Card(
                      child: InkWell(
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddPlayPage(
                                repository: widget.repository,
                                existingPlay: play,
                              ),
                            ),
                          );
                          if (updated == true) {
                            setState(() {});
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (play.gameThumbnailUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: play.gameThumbnailUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      cacheManager: QuokkaCacheManager.instance,
                                      placeholder: (context, url) => Container(width: 60, height: 60, color: Colors.grey[200]),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  )
                              else
                                const SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: Icon(Icons.videogame_asset)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(play.gameName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text(
                                        '${play.date.year}-${play.date.month}-${play.date.day} ${play.durationMinutes != null ? "• ${play.durationMinutes}m" : ""}'),
                                    if (playersText.isNotEmpty)
                                      Text('Players: $playersText',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    if (play.winnerId != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.emoji_events,
                                              size: 14, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Winner: ${widget.repository.players.cast<dynamic>().firstWhere((p) => p.id == play.winnerId, orElse: () => null)?.name ?? "Unknown"}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit, color: Colors.grey, size: 20),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.grey, size: 20),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Log'),
                                          content: const Text(
                                              'Remove this play session?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('Cancel')),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, true),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        color: Colors.red))),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await widget.repository
                                            .removePlayRecord(play.id);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final chips = <Widget>[];
    
    if (_currentFilter.gameId != null) {
      final game = widget.repository.ownedGames.cast<BoardGame?>().firstWhere((g) => g?.id == _currentFilter.gameId, orElse: () => null);
      if (game != null) {
        chips.add(_FilterChip(
          label: 'Game: ${game.name}',
          onDeleted: () => setState(() => _currentFilter = _currentFilter.copyWith(gameId: () => null)),
        ));
      }
    }
    
    if (_currentFilter.winnerId != null) {
      final player = widget.repository.players.cast<dynamic>().firstWhere((p) => p.id == _currentFilter.winnerId, orElse: () => null);
      if (player != null) {
        chips.add(_FilterChip(
          label: 'Winner: ${player.name}',
          onDeleted: () => setState(() => _currentFilter = _currentFilter.copyWith(winnerId: () => null)),
        ));
      }
    }
    
    for (final pid in _currentFilter.playerIds) {
      final player = widget.repository.players.cast<dynamic>().firstWhere((p) => p.id == pid, orElse: () => null);
      if (player != null) {
        chips.add(_FilterChip(
          label: 'Player: ${player.name}',
          onDeleted: () {
            setState(() {
              final newIds = List<String>.from(_currentFilter.playerIds)..remove(pid);
              _currentFilter = _currentFilter.copyWith(playerIds: newIds);
            });
          },
        ));
      }
    }
    
    if (_currentFilter.dateRange != null) {
      chips.add(_FilterChip(
        label: 'Date Range',
        onDeleted: () => setState(() => _currentFilter = _currentFilter.copyWith(dateRange: () => null)),
      ));
    }

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlayFilterSheet(
        repository: widget.repository,
        initialFilter: _currentFilter,
        onApply: (filter) => setState(() => _currentFilter = filter),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: onDeleted,
        deleteIconColor: Colors.grey,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
