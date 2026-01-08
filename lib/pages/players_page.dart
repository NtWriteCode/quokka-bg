import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quokka/models/player.dart';
import 'package:quokka/repositories/game_repository.dart';

class PlayersPage extends StatefulWidget {
  final GameRepository repository;

  const PlayersPage({super.key, required this.repository});

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    _loadPlayers();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    await widget.repository.loadPlayers();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddPlayerDialog() {
    final nameController = TextEditingController();
    Color selectedColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Player'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Player Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Associated Color'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Colors.primaries.map((color) {
                    final isSelected = selectedColor.value == color.value;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                
                // Check for duplicate name
                if (widget.repository.players.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A player with this name already exists!')),
                  );
                  return;
                }

                final newPlayer = Player(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  colorValue: selectedColor.value,
                );

                await widget.repository.addPlayer(newPlayer);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Players')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlayerDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.repository.players.isEmpty
              ? const Center(child: Text('No players yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.repository.players.length,
                  itemBuilder: (context, index) {
                    final player = widget.repository.players[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(player.colorValue),
                        ),
                        title: Text(
                          player.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wins: ${widget.repository.getWinCountForPlayer(player.id)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                            if (widget.repository.getStrongestGameForPlayer(player.id) != null)
                              Text(
                                'Signature game: ${widget.repository.getStrongestGameForPlayer(player.id)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Player'),
                                content: Text('Are you sure you want to remove ${player.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await widget.repository.removePlayer(player.id);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
