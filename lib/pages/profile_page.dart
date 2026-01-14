import 'package:flutter/material.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/models/user_stats.dart';
import 'package:quokka/services/achievement_service.dart';
import 'package:quokka/pages/settings_page.dart';
import 'package:quokka/models/player.dart';
import 'dart:math';

class ProfilePage extends StatefulWidget {
  final GameRepository repository;
  const ProfilePage({super.key, required this.repository});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _showAllXpHistory = false;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
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
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlayerDialog(Player player) {
    final nameController = TextEditingController(text: player.name);
    Color selectedColor = Color(player.colorValue);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Player'),
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
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Player'),
                    content: Text('Are you sure you want to remove ${player.name}? This will NOT delete their play history.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await widget.repository.removePlayer(player.id);
                  if (mounted) {
                    Navigator.pop(context); // Close edit dialog
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                
                final updatedPlayer = Player(
                  id: player.id,
                  name: name,
                  colorValue: selectedColor.value,
                );

                await widget.repository.updatePlayer(updatedPlayer);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.repository.userStats;
    final progress = stats.totalXp / stats.xpForNextLevel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(repository: widget.repository),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Level & XP Bar
            _buildLevelHeader(stats, progress),
            
            const SizedBox(height: 32),
            
            // Players Section
            _buildSectionTitle('Gaming Group'),
            _buildPlayersSection(),

            const SizedBox(height: 32),
            
            // Achievements Section
            _buildSectionTitle('Achievements'),
            _buildAchievementList(stats),
            
            const SizedBox(height: 32),
            
            // XP History Section
            _buildSectionTitle('XP History'),
            _buildXpHistory(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelHeader(UserStats stats, double progress) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text('${stats.level}', 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            const Text('Level', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 8),
            Text('${stats.totalXp} / ${stats.xpForNextLevel} XP', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAchievementList(UserStats stats) {
    final all = AchievementService.allAchievements;
    final categories = <String>{};
    for (var ach in all) {
      categories.add(ach.category);
    }

    return Column(
      children: categories.map((cat) {
        final catAchievements = all.where((a) => a.category == cat).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                cat.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
            ),
            ...catAchievements.map((ach) {
              final isUnlocked = stats.unlockedAchievementIds.contains(ach.id);
              Color tierColor;
              switch (ach.tier) {
                case AchievementTier.bronze: tierColor = Colors.brown; break;
                case AchievementTier.silver: tierColor = Colors.grey; break;
                case AchievementTier.gold: tierColor = Colors.amber; break;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isUnlocked ? 2 : 0,
                color: isUnlocked ? null : Colors.grey[50],
                child: Opacity(
                  opacity: isUnlocked ? 1.0 : 0.5,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isUnlocked ? tierColor.withOpacity(0.1) : Colors.grey[200],
                      child: Icon(
                        isUnlocked ? Icons.emoji_events : Icons.lock_outline,
                        color: isUnlocked ? tierColor : Colors.grey[400],
                      ),
                    ),
                    title: Text(
                      ach.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? null : Colors.grey[700],
                      ),
                    ),
                    subtitle: Text(ach.description),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${ach.xpReward} XP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (isUnlocked)
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPlayersSection() {
    final players = widget.repository.players;
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: players.length + 1,
        itemBuilder: (context, index) {
          if (index == players.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showAddPlayerDialog,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.add, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Add', style: TextStyle(fontSize: 11)),
                ],
              ),
            );
          }
          final player = players[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _showEditPlayerDialog(player),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(player.colorValue),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    player.name, 
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildXpHistory(UserStats stats) {
    if (stats.xpHistory.isEmpty) return const Text('No XP earned yet.');
    
    final displayCount = _showAllXpHistory ? stats.xpHistory.length : min(10, stats.xpHistory.length);
    final hasMore = stats.xpHistory.length > 10;
    
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final entry = stats.xpHistory[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.bolt, color: Colors.amber)),
                title: Text(entry.reason),
                subtitle: Text('${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')} - ${entry.date.day}/${entry.date.month}/${entry.date.year}'),
                trailing: Text('+${entry.amount} XP', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            );
          },
        ),
        if (hasMore)
          TextButton.icon(
            onPressed: () => setState(() => _showAllXpHistory = !_showAllXpHistory),
            icon: Icon(_showAllXpHistory ? Icons.expand_less : Icons.expand_more),
            label: Text(_showAllXpHistory 
              ? 'Show Less' 
              : 'Show All (${stats.xpHistory.length} entries)'),
          ),
      ],
    );
  }
}
