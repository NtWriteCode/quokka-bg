import 'package:flutter/material.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/models/user_stats.dart';
import 'package:quokka/services/achievement_service.dart';
import 'package:quokka/pages/settings_page.dart';
import 'package:quokka/models/player.dart';
import 'package:quokka/helpers/title_helper.dart';
import 'package:quokka/widgets/gradient_background.dart';
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

  void _showCustomizationDialog(UserStats stats) async {
    await showDialog(
      context: context,
      builder: (context) => _CustomizationDialog(
        repository: widget.repository,
        stats: stats,
      ),
    );
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
    final title = stats.customTitle ?? TitleHelper.getTitleForLevel(stats.level);
    final gradient = stats.customBackgroundTier != null 
        ? TitleHelper.getBackgroundForLevel(stats.customBackgroundTier! * 5)
        : TitleHelper.getBackgroundForLevel(stats.level);
    final tier = stats.customBackgroundTier ?? (stats.level / 5).floor();
    
    return GestureDetector(
      onTap: () => _showCustomizationDialog(stats),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: GradientBackground(
          gradient: gradient,
          tier: tier,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Info icon in top-left corner
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: _showXpInfoDialog,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Edit icon in top-right corner
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          child: Text('${stats.level}', 
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.totalXp.round()} / ${stats.xpForNextLevel} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                      ),
                    ),
                const SizedBox(height: 16),
                // Streak bonus bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Play Streak Bonus: ${stats.consecutiveDays} days • +${(stats.streakBonus * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStreakBar(stats.streakBonus),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStreakLabel('10%', 1),
                        _buildStreakLabel('30%', 3),
                        _buildStreakLabel('60%', 6),
                        _buildStreakLabel('100%', 10),
                      ],
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBar(double streakBonus) {
    // Max streak is 100% (1.0), divide into 10 segments (each 10%)
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: List.generate(10, (index) {
            final segmentThreshold = (index + 1) * 0.1;
            final isActive = streakBonus >= segmentThreshold;
            final isPartial = streakBonus > index * 0.1 && streakBonus < segmentThreshold;
            
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(left: index > 0 ? 2 : 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [Colors.orange.shade400, Colors.deepOrange.shade600]
                        : isPartial
                            ? [Colors.orange.shade300, Colors.orange.shade100]
                            : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.1)],
                  ),
                ),
                child: isActive
                    ? const Center(
                        child: Icon(
                          Icons.local_fire_department,
                          size: 12,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStreakLabel(String label, int daysRequired) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white70,
        shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
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
                trailing: Text('+${entry.amount.round()} XP', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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

  void _showXpInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('XP Rewards'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Earn XP by:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildXpInfoItem(Icons.add_circle, 'Add game to collection', '10 XP'),
              _buildXpInfoItem(Icons.favorite_border, 'Add to wishlist', '1 XP'),
              _buildXpInfoItem(Icons.shopping_cart, 'Wishlist → Collection', '5 XP'),
              _buildXpInfoItem(Icons.sell, 'Sell a game', '3 XP'),
              _buildXpInfoItem(Icons.handshake, 'Lend a game', '5 XP'),
              _buildXpInfoItem(Icons.casino, 'Play a game', '3 XP × players'),
              _buildXpInfoItem(Icons.login, 'Daily login', '1 XP'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Achievements:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildXpInfoItem(Icons.emoji_events, 'Bronze achievement', '10 XP', color: Colors.brown),
              _buildXpInfoItem(Icons.emoji_events, 'Silver achievement', '25 XP', color: Colors.grey),
              _buildXpInfoItem(Icons.emoji_events, 'Gold achievement', '50 XP', color: Colors.amber),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Play Streak Bonus: Play games daily to earn up to +100% XP!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildXpInfoItem(IconData icon, String action, String xp, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(action, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            xp,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomizationDialog extends StatefulWidget {
  final GameRepository repository;
  final UserStats stats;

  const _CustomizationDialog({
    required this.repository,
    required this.stats,
  });

  @override
  State<_CustomizationDialog> createState() => _CustomizationDialogState();
}

class _CustomizationDialogState extends State<_CustomizationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedTitle;
  int? _selectedBackgroundTier;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedTitle = widget.stats.customTitle;
    _selectedBackgroundTier = widget.stats.customBackgroundTier;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveCustomization() async {
    final updatedStats = widget.stats.copyWith(
      customTitle: _selectedTitle,
      customBackgroundTier: _selectedBackgroundTier,
    );
    
    // Update the stats through repository
    await widget.repository.updateUserStatsCustomization(updatedStats);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedTitles = TitleHelper.getUnlockedTitles(widget.stats.level);
    final currentTitle = TitleHelper.getTitleForLevel(widget.stats.level);
    final unlockedBackgrounds = TitleHelper.getUnlockedBackgrounds(widget.stats.level);
    final maxTier = (widget.stats.level / 5).floor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Customize Profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Title'),
                Tab(text: 'Background'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTitleSelection(unlockedTitles, currentTitle),
                  _buildBackgroundSelection(unlockedBackgrounds, maxTier),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedTitle = null;
                        _selectedBackgroundTier = null;
                      });
                    },
                    child: const Text('Reset to Default'),
                  ),
                  ElevatedButton(
                    onPressed: _saveCustomization,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSelection(List<String> unlockedTitles, String currentTitle) {
    // Determine if user wants default (null) or explicitly selected current title
    final isUsingDefault = _selectedTitle == null;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Auto (use current level title)
        Card(
          color: isUsingDefault ? Colors.green.shade50 : null,
          child: RadioListTile<String?>(
            title: Text(currentTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Auto (current level title)'),
            value: null,
            groupValue: _selectedTitle,
            onChanged: (val) => setState(() => _selectedTitle = val),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Unlocked Titles:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...unlockedTitles.reversed.map((title) {
          final isSelected = _selectedTitle == title;
          return Card(
            color: isSelected ? Colors.blue.shade50 : null,
            child: RadioListTile<String?>(
              title: Text(title),
              subtitle: title == currentTitle ? const Text('Current level') : null,
              value: title,
              groupValue: _selectedTitle,
              onChanged: (val) => setState(() => _selectedTitle = val),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBackgroundSelection(List<LinearGradient> unlockedBackgrounds, int maxTier) {
    // Group backgrounds by theme
    final categories = [
      {'name': '🌍 Earth (Lv 1-19)', 'start': 0, 'end': 3},
      {'name': '🌊 Ocean (Lv 20-39)', 'start': 4, 'end': 7},
      {'name': '🔥 Fire (Lv 40-59)', 'start': 8, 'end': 11},
      {'name': '👑 Royal (Lv 60-79)', 'start': 12, 'end': 15},
      {'name': '🌌 Cosmic (Lv 80-100+)', 'start': 16, 'end': 20},
    ];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: categories.map((category) {
        final categoryName = category['name'] as String;
        final start = category['start'] as int;
        final end = category['end'] as int;
        
        // Filter unlocked backgrounds for this category
        final categoryBackgrounds = <int>[];
        for (int i = start; i <= end && i < unlockedBackgrounds.length; i++) {
          categoryBackgrounds.add(i);
        }
        
        if (categoryBackgrounds.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                categoryName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: categoryBackgrounds.length,
              itemBuilder: (context, idx) {
                final index = categoryBackgrounds[idx];
                final gradient = unlockedBackgrounds[index];
                final tierName = TitleHelper.getTierNameForLevel(index * 5);
                final isCurrentTier = index == (widget.stats.level / 5).floor();
                final isSelected = _selectedBackgroundTier == index;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedBackgroundTier = index),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.blue 
                            : (isCurrentTier ? Colors.green : Colors.grey.shade300),
                        width: isSelected ? 3 : (isCurrentTier ? 2 : 1),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GradientBackground(
                        gradient: gradient,
                        tier: index,
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tierName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            if (isCurrentTier)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(Icons.star, color: Colors.white, size: 20),
                              ),
                            if (isSelected)
                              const Positioned(
                                top: 8,
                                left: 8,
                                child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }
}
