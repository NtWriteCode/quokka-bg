import 'package:flutter/material.dart';
import 'package:quokka/models/play_record.dart';
import 'package:quokka/pages/add_play_page.dart';
import 'package:quokka/repositories/game_repository.dart';

class PlayedGamesPage extends StatefulWidget {
  final GameRepository repository;

  const PlayedGamesPage({super.key, required this.repository});

  @override
  State<PlayedGamesPage> createState() => _PlayedGamesPageState();
}

class _PlayedGamesPageState extends State<PlayedGamesPage> {
  bool _isLoading = true;

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
    final plays = List<PlayRecord>.from(widget.repository.playRecords)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Play History')),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : plays.isEmpty
              ? const Center(child: Text('No plays logged yet.'))
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
                                  child: Image.network(play.gameThumbnailUrl!,
                                      width: 60, height: 60, fit: BoxFit.cover),
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
    );
  }
}
