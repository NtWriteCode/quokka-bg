import 'package:flutter/material.dart';
import 'package:quokka/models/board_game.dart';
import 'package:quokka/models/player.dart';
import 'package:quokka/models/play_record.dart';
import 'package:quokka/repositories/game_repository.dart';

class AddPlayPage extends StatefulWidget {
  final GameRepository repository;
  final PlayRecord? existingPlay;

  const AddPlayPage({super.key, required this.repository, this.existingPlay});

  @override
  State<AddPlayPage> createState() => _AddPlayPageState();
}

class _AddPlayPageState extends State<AddPlayPage> {
  BoardGame? _selectedGame;
  DateTime _selectedDate = DateTime.now();
  final _durationController = TextEditingController();
  final List<Player> _selectedPlayers = [];
  final Map<String, TextEditingController> _scoreControllers = {};
  String? _manualWinnerId;
  bool _isWinnerOverridden = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPlay != null) {
      final play = widget.existingPlay!;
      _selectedDate = play.date;
      _durationController.text = play.durationMinutes?.toString() ?? '';
      _manualWinnerId = play.winnerId;
      _isWinnerOverridden = play.winnerId != null;

      _selectedGame = widget.repository.ownedGames.cast<BoardGame?>().firstWhere(
        (g) => g?.id == play.gameId,
        orElse: () => null,
      );

      for (var playerId in play.playerScores.keys) {
        final player = widget.repository.players.cast<Player?>().firstWhere(
          (p) => p?.id == playerId,
          orElse: () => null,
        );
        if (player != null) {
          _selectedPlayers.add(player);
          final controller = TextEditingController(text: play.playerScores[playerId]?.toString() ?? '');
          _scoreControllers[playerId] = controller;
          controller.addListener(_updateWinner);
        }
      }
    }
  }

  void _onPlayerToggle(Player player, bool selected) {
    setState(() {
      if (selected) {
        _selectedPlayers.add(player);
        _scoreControllers[player.id] = TextEditingController();
        _scoreControllers[player.id]!.addListener(_updateWinner);
      } else {
        _selectedPlayers.removeWhere((p) => p.id == player.id);
        _scoreControllers[player.id]?.dispose();
        _scoreControllers.remove(player.id);
        if (_manualWinnerId == player.id) {
          _manualWinnerId = null;
          _isWinnerOverridden = false;
        }
        _updateWinner();
      }
    });
  }

  void _updateWinner() {
    if (_isWinnerOverridden) return;
    String? topPlayerId;
    int? topScore;
    _scoreControllers.forEach((playerId, controller) {
      final scoreCount = int.tryParse(controller.text);
      if (scoreCount != null) {
        if (topScore == null || scoreCount > topScore!) {
          topScore = scoreCount;
          topPlayerId = playerId;
        }
      }
    });
    setState(() => _manualWinnerId = topPlayerId);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showGamePicker() {
    final ownedGames = widget.repository.ownedGames.where((g) => g.status != GameStatus.wishlist).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GamePickerSheet(
        repository: widget.repository,
        games: ownedGames,
        onSelected: (game) {
          setState(() => _selectedGame = game);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _savePlay() async {
    if (_selectedGame == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a game')));
      return;
    }
    final Map<String, int?> scores = {};
    _scoreControllers.forEach((playerId, controller) {
      scores[playerId] = int.tryParse(controller.text);
    });
    final record = PlayRecord(
      id: widget.existingPlay?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      gameId: _selectedGame!.id,
      gameName: _selectedGame!.name,
      gameThumbnailUrl: _selectedGame!.customThumbnailUrl,
      date: _selectedDate,
      durationMinutes: int.tryParse(_durationController.text),
      playerScores: scores,
      winnerId: _manualWinnerId,
    );
    if (widget.existingPlay != null) {
      await widget.repository.updatePlayRecord(record);
    } else {
      await widget.repository.addPlayRecord(record);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final allPlayers = widget.repository.players;
    final recent = widget.repository.getRecentlyPlayedGames(limit: 5);

    return Scaffold(
      appBar: AppBar(title: Text(widget.existingPlay != null ? 'Edit Play Session' : 'New Play Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recent.isNotEmpty) ...[
              const Text('Quick Select (Recent)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: recent.map((game) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      avatar: game.customThumbnailUrl != null ? CircleAvatar(backgroundImage: NetworkImage(game.customThumbnailUrl!)) : null,
                      label: Text(game.name),
                      onPressed: () => setState(() => _selectedGame = game),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            InkWell(
              onTap: _showGamePicker,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Game',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.videogame_asset),
                  suffixIcon: Icon(Icons.search),
                ),
                child: Text(_selectedGame?.name ?? 'Tap to search games...'),
              ),
            ),
            const SizedBox(height: 16),
            
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Date: ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Time Spent (minutes)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            const Text('Players & Scores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              children: allPlayers.map((player) {
                final isSelected = _selectedPlayers.any((p) => p.id == player.id);
                return FilterChip(
                  label: Text(player.name),
                  selected: isSelected,
                  selectedColor: Color(player.colorValue).withOpacity(0.3),
                  onSelected: (val) => _onPlayerToggle(player, val),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (_selectedPlayers.isNotEmpty) ...[
              ..._selectedPlayers.map((player) {
                final isWinner = _manualWinnerId == player.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Color(player.colorValue), radius: 12),
                      const SizedBox(width: 8),
                      Expanded(child: Text(player.name)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _scoreControllers[player.id],
                          decoration: const InputDecoration(labelText: 'Score', isDense: true),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      IconButton(
                        icon: Icon(isWinner ? Icons.emoji_events : Icons.emoji_events_outlined),
                        color: isWinner ? Colors.amber : Colors.grey,
                        onPressed: () {
                          setState(() {
                            _manualWinnerId = player.id;
                            _isWinnerOverridden = true;
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _savePlay,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(widget.existingPlay != null ? 'Update Session' : 'Save Session'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    for (var c in _scoreControllers.values) c.dispose();
    super.dispose();
  }
}

class _GamePickerSheet extends StatefulWidget {
  final GameRepository repository;
  final List<BoardGame> games;
  final ValueChanged<BoardGame> onSelected;

  const _GamePickerSheet({
    required this.repository,
    required this.games,
    required this.onSelected,
  });

  @override
  State<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<_GamePickerSheet> {
  String _query = '';
  bool _searchBgg = false;
  List<Map<String, dynamic>> _bggResults = [];
  bool _isSearching = false;

  Future<void> _performBggSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _bggResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await widget.repository.searchBgg(query);
    setState(() {
      _bggResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.games.where((g) => g.name.toLowerCase().contains(_query.toLowerCase())).toList();
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: _searchBgg ? 'Search BGG...' : 'Search collection...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                    ),
                    onChanged: (val) {
                      setState(() => _query = val);
                      if (_searchBgg) {
                        _performBggSearch(val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {
                    setState(() {
                      _searchBgg = !_searchBgg;
                      if (_searchBgg && _query.isNotEmpty) {
                        _performBggSearch(_query);
                      }
                    });
                  },
                  icon: Icon(_searchBgg ? Icons.inventory_2 : Icons.public),
                  tooltip: _searchBgg ? 'Back to Collection' : 'Search BGG',
                ),
              ],
            ),
          ),
          if (_searchBgg && _query.isEmpty)
             const Expanded(child: Center(child: Text('Type to search games on BGG'))),
          if (!_searchBgg || _query.isNotEmpty)
            Expanded(
              child: _isSearching 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _searchBgg ? _bggResults.length : filtered.length,
                    itemBuilder: (context, index) {
                      if (_searchBgg) {
                        final item = _bggResults[index];
                        return ListTile(
                          title: Text(item['name'] ?? 'Unknown'),
                          subtitle: Text(item['yearpublished']?.toString() ?? ''),
                          onTap: () async {
                            // Show loading
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );
                            
                            BoardGame finalGame;
                            try {
                              final detailsMap = await widget.repository.fetchGameDetails(item['id'].toString());
                              if (detailsMap != null) {
                                finalGame = widget.repository.convertDetailsToLocal(detailsMap)!;
                              } else {
                                finalGame = widget.repository.convertToLocal(searchResult: item);
                              }
                            } catch (e) {
                              finalGame = widget.repository.convertToLocal(searchResult: item);
                            }

                            // Convert to unowned game
                            final unownedGame = finalGame.copyWith(status: GameStatus.unowned);
                            await widget.repository.addGame(unownedGame);
                            
                            if (mounted) {
                              Navigator.pop(context); // Close loading
                              widget.onSelected(unownedGame);
                            }
                          },
                        );
                      } else {
                        final game = filtered[index];
                        return ListTile(
                          leading: game.customThumbnailUrl != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(game.customThumbnailUrl!, width: 40, height: 40, fit: BoxFit.cover))
                            : const Icon(Icons.videogame_asset),
                          title: Text(game.name),
                          onTap: () => widget.onSelected(game),
                        );
                      }
                    },
                  ),
            ),
        ],
      ),
    );
  }
}
