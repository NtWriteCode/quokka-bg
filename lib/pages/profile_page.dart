import 'package:flutter/material.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/models/user_stats.dart';
import 'package:quokka/models/profile_effects.dart';
import 'package:quokka/services/achievement_service.dart';
import 'package:quokka/pages/settings_page.dart';
import 'package:quokka/models/player.dart';
import 'package:quokka/helpers/title_helper.dart';
import 'package:quokka/widgets/gradient_background.dart';
import 'package:quokka/widgets/animated_gradient_background.dart';
import 'package:quokka/widgets/pattern_overlay.dart';
import 'package:quokka/widgets/shimmer_effect.dart';
import 'package:quokka/widgets/particle_effect.dart';
import 'package:quokka/widgets/pulse_effect.dart';
import 'package:quokka/widgets/level_badge.dart';
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
    // Get title from selected achievement, or use display name
    String? title;
    if (stats.selectedAchievementTitleId != null) {
      final achievement = widget.repository.getUnlockedAchievements()
          .firstWhere((a) => a.id == stats.selectedAchievementTitleId, 
                      orElse: () => Achievement(id: '', title: '', description: '', 
                                               tier: AchievementTier.bronze, xpReward: 0, category: ''));
      if (achievement.id.isNotEmpty) {
        title = achievement.title;
      }
    }
    
    final gradient = stats.customBackgroundTier != null 
        ? TitleHelper.getBackgroundForLevel(stats.customBackgroundTier! * 5)
        : TitleHelper.getBackgroundForLevel(stats.level);
    final tier = stats.customBackgroundTier ?? (stats.level / 5).floor();
    final effects = stats.profileEffects;
    
    // Build border decoration with effects
    final borderShadows = <BoxShadow>[];
    
    // Add glow effect if enabled (clamp opacity to 0.0-1.0)
    if (effects.glowEnabled) {
      borderShadows.addAll([
        BoxShadow(
          color: Colors.white.withOpacity((0.5 * effects.glowIntensity).clamp(0.0, 1.0)),
          blurRadius: 30 * effects.glowIntensity,
          spreadRadius: 8 * effects.glowIntensity,
        ),
        BoxShadow(
          color: Colors.white.withOpacity((0.3 * effects.glowIntensity).clamp(0.0, 1.0)),
          blurRadius: 50 * effects.glowIntensity,
          spreadRadius: 15 * effects.glowIntensity,
        ),
      ]);
    }
    
    final borderDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: effects.glowEnabled 
          ? Border.all(
              color: Colors.white.withOpacity((0.7 * effects.glowIntensity).clamp(0.0, 1.0)),
              width: 3 * effects.glowIntensity,
            )
          : null,
      boxShadow: borderShadows.isNotEmpty ? borderShadows : null,
    );
    
    // Use a golden/yellow glow that's visible on any background
    // Use custom glow color or default to amber
    final glowColor = effects.glowColor ?? Colors.amber;
    
    final finalDecoration = effects.glowEnabled 
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // No border - just pure glow effect
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity((0.6 * effects.glowIntensity).clamp(0.0, 1.0)),
                blurRadius: 20 * effects.glowIntensity,
                spreadRadius: 5 * effects.glowIntensity,
              ),
              BoxShadow(
                color: glowColor.withOpacity((0.4 * effects.glowIntensity).clamp(0.0, 1.0)),
                blurRadius: 40 * effects.glowIntensity,
                spreadRadius: 10 * effects.glowIntensity,
              ),
              BoxShadow(
                color: glowColor.withOpacity((0.3 * effects.glowIntensity).clamp(0.0, 1.0)),
                blurRadius: 60 * effects.glowIntensity,
                spreadRadius: 15 * effects.glowIntensity,
              ),
            ],
          )
        : borderDecoration;
    
    return PulseEffect(
      enabled: effects.pulseEnabled,
      speed: effects.pulseSpeed,
      child: GestureDetector(
        onTap: () => _showCustomizationDialog(stats),
        behavior: HitTestBehavior.deferToChild,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            decoration: finalDecoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ParticleEffect(
                  enabled: effects.particlesEnabled,
                  particleType: effects.particleType ?? 'stars',
                  density: effects.particleDensity,
                  color: effects.particleColor,
                  child: ShimmerEffect(
                    enabled: effects.shimmerEnabled,
                    child: PatternOverlay(
                      pattern: effects.selectedPattern,
                      child: AnimatedGradientBackground(
                        gradient: gradient,
                        enabled: effects.animatedGradientEnabled,
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
                        LevelBadge(
                          level: stats.level,
                          badgeType: effects.selectedLevelBadge,
                          size: 80,
                        ),
                        const SizedBox(height: 8),
                        if (title != null)
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
                ),
              ),
                ),
                  ),
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

              // Get game info for game-specific achievements
              String? gameHint;
              if (ach.id == 'own_solo_game') {
                final soloGame = widget.repository.getSoloOnlyGame();
                if (soloGame != null) {
                  gameHint = '${soloGame.name} (1 player)';
                }
              } else if (ach.id == 'own_duo_game') {
                final duoGame = widget.repository.getDuoOnlyGame();
                if (duoGame != null) {
                  gameHint = '${duoGame.name} (2 players)';
                }
              } else if (ach.id == 'own_party_game') {
                final partyGame = widget.repository.getPartyGame();
                if (partyGame != null) {
                  gameHint = '${partyGame.name} (${partyGame.minPlayers}-${partyGame.maxPlayers} players)';
                }
              } else if (ach.id == 'complexity_simplest') {
                final simplest = widget.repository.getSimplestGame();
                if (simplest != null) {
                  gameHint = '${simplest.name} (Weight: ${simplest.averageWeight?.toStringAsFixed(2)})';
                }
              } else if (ach.id == 'complexity_hardest') {
                final hardest = widget.repository.getHardestGame();
                if (hardest != null) {
                  gameHint = '${hardest.name} (Weight: ${hardest.averageWeight?.toStringAsFixed(2)})';
                }
              } else if (ach.id == 'rating_lowest') {
                final lowest = widget.repository.getLowestRatedGame();
                if (lowest != null) {
                  gameHint = '${lowest.name} (Rating: ${lowest.averageRating?.toStringAsFixed(2)})';
                }
              } else if (ach.id == 'rating_highest') {
                final highest = widget.repository.getHighestRatedGame();
                if (highest != null) {
                  gameHint = '${highest.name} (Rating: ${highest.averageRating?.toStringAsFixed(2)})';
                }
              } else if (ach.id == 'buy_new_best_rated') {
                final highest = widget.repository.getHighestRatedGame();
                if (highest != null && highest.averageRating != null) {
                  final rating = highest.averageRating!;
                  if (isUnlocked) {
                    gameHint = 'Current best: ${rating.toStringAsFixed(2)} ✨';
                  } else if (rating >= 9.0) {
                    gameHint = 'Current best: ${rating.toStringAsFixed(2)} ⚡ (Eligible for auto-unlock!)';
                  } else {
                    gameHint = 'Current best: ${rating.toStringAsFixed(2)} (≥9.0 auto-unlocks)';
                  }
                }
              } else if (ach.id == 'buy_new_worst_rated') {
                final lowest = widget.repository.getLowestRatedGame();
                if (lowest != null && lowest.averageRating != null) {
                  final rating = lowest.averageRating!;
                  if (isUnlocked) {
                    gameHint = 'Current worst: ${rating.toStringAsFixed(2)} ✨';
                  } else if (rating <= 2.0) {
                    gameHint = 'Current worst: ${rating.toStringAsFixed(2)} ⚡ (Eligible for auto-unlock!)';
                  } else {
                    gameHint = 'Current worst: ${rating.toStringAsFixed(2)} (≤2.0 auto-unlocks)';
                  }
                }
              } else if (ach.id == 'buy_new_most_complex') {
                final hardest = widget.repository.getHardestGame();
                if (hardest != null && hardest.averageWeight != null) {
                  final weight = hardest.averageWeight!;
                  if (isUnlocked) {
                    gameHint = 'Current most: ${weight.toStringAsFixed(2)} ✨';
                  } else if (weight >= 4.5) {
                    gameHint = 'Current most: ${weight.toStringAsFixed(2)} ⚡ (Eligible for auto-unlock!)';
                  } else {
                    gameHint = 'Current most: ${weight.toStringAsFixed(2)} (≥4.5 auto-unlocks)';
                  }
                }
              } else if (ach.id == 'buy_new_least_complex') {
                final simplest = widget.repository.getSimplestGame();
                if (simplest != null && simplest.averageWeight != null) {
                  final weight = simplest.averageWeight!;
                  if (isUnlocked) {
                    gameHint = 'Current least: ${weight.toStringAsFixed(2)} ✨';
                  } else if (weight <= 1.2) {
                    gameHint = 'Current least: ${weight.toStringAsFixed(2)} ⚡ (Eligible for auto-unlock!)';
                  } else {
                    gameHint = 'Current least: ${weight.toStringAsFixed(2)} (≤1.2 auto-unlocks)';
                  }
                }
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ach.description),
                        if (gameHint != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '🎯 $gameHint',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? Colors.green : Colors.blue,
                            ),
                          ),
                        ],
                      ],
                    ),
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
              _buildXpInfoItem(Icons.emoji_events, 'Bronze achievement', '20 XP', color: Colors.brown),
              _buildXpInfoItem(Icons.emoji_events, 'Silver achievement', '40 XP', color: Colors.grey),
              _buildXpInfoItem(Icons.emoji_events, 'Gold achievement', '80 XP', color: Colors.amber),
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
                        'Play Streak Bonus: Play games daily to earn up to +100% XP on plays only!',
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
  String? _selectedAchievementTitleId;
  int? _selectedBackgroundTier;
  late ProfileEffects _profileEffects;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedAchievementTitleId = widget.stats.selectedAchievementTitleId;
    _selectedBackgroundTier = widget.stats.customBackgroundTier;
    _profileEffects = widget.stats.profileEffects;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveCustomization() async {
    final updatedStats = widget.stats.copyWith(
      selectedAchievementTitleId: _selectedAchievementTitleId,
      customBackgroundTier: _selectedBackgroundTier,
      profileEffects: _profileEffects,
    );
    
    // Update the stats through repository
    await widget.repository.updateUserStatsCustomization(updatedStats);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedAchievements = widget.repository.getUnlockedAchievements();
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
                Tab(text: 'Effects'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTitleSelection(unlockedAchievements),
                  _buildBackgroundSelection(unlockedBackgrounds, maxTier),
                  _buildEffectsSelection(),
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
                        _selectedAchievementTitleId = null;
                        _selectedBackgroundTier = null;
                        _profileEffects = const ProfileEffects();
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

  Widget _buildTitleSelection(List<Achievement> unlockedAchievements) {
    // Determine if user wants default (null) or explicitly selected achievement title
    final isUsingDefault = _selectedAchievementTitleId == null;
    
    // Group achievements by category
    final achievementsByCategory = <String, List<Achievement>>{};
    for (final achievement in unlockedAchievements) {
      achievementsByCategory.putIfAbsent(achievement.category, () => []).add(achievement);
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // No custom title (show display name only)
        Card(
          color: isUsingDefault ? Colors.green.shade50 : null,
          child: RadioListTile<String?>(
            title: Text(widget.stats.displayName.isEmpty ? 'Player' : widget.stats.displayName, 
                       style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('No title (default)'),
            value: null,
            groupValue: _selectedAchievementTitleId,
            onChanged: (val) => setState(() => _selectedAchievementTitleId = val),
          ),
        ),
        const SizedBox(height: 16),
        if (unlockedAchievements.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unlock achievements to use them as titles!',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ...achievementsByCategory.entries.map((entry) {
            final category = entry.key;
            final achievements = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    category,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                ...achievements.map((achievement) {
                  final isSelected = _selectedAchievementTitleId == achievement.id;
                  Color? tierColor;
                  switch (achievement.tier) {
                    case AchievementTier.bronze:
                      tierColor = Colors.brown.shade300;
                      break;
                    case AchievementTier.silver:
                      tierColor = Colors.grey.shade400;
                      break;
                    case AchievementTier.gold:
                      tierColor = Colors.amber.shade400;
                      break;
                  }
                  
                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    child: RadioListTile<String?>(
                      title: Row(
                        children: [
                          Icon(Icons.emoji_events, color: tierColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(achievement.title)),
                        ],
                      ),
                      subtitle: Text(achievement.description),
                      value: achievement.id,
                      groupValue: _selectedAchievementTitleId,
                      onChanged: (val) => setState(() => _selectedAchievementTitleId = val),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          }),
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

  Widget _buildEffectsSelection() {
    final level = widget.stats.level;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Patterns Section (Unlocks at Level 5)
        const Text(
          '🎨 Patterns',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildPatternOption('None', null, true),
        _buildPatternOption('Diagonal Stripes', 'stripes', ProfileEffects.isPatternUnlocked('stripes', level)),
        _buildPatternOption('Dots', 'dots', ProfileEffects.isPatternUnlocked('dots', level)),
        _buildPatternOption('Waves', 'waves', ProfileEffects.isPatternUnlocked('waves', level)),
        _buildPatternOption('Hexagons', 'hexagons', ProfileEffects.isPatternUnlocked('hexagons', level)),
        
        const SizedBox(height: 24),
        
        // Effects Section (Unlocks at Level 10)
        const Text(
          '✨ Effects',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildEffectToggle('Shimmer', 'shimmer', level, _profileEffects.shimmerEnabled, (val) {
          setState(() {
            _profileEffects = _profileEffects.copyWith(shimmerEnabled: val);
          });
        }),
        _buildEffectToggle('Animated Gradient', 'animatedGradient', level, _profileEffects.animatedGradientEnabled, (val) {
          setState(() {
            _profileEffects = _profileEffects.copyWith(animatedGradientEnabled: val);
          });
        }),
        _buildEffectToggle('Glow', 'glow', level, _profileEffects.glowEnabled, (val) {
          setState(() {
            _profileEffects = _profileEffects.copyWith(glowEnabled: val);
          });
        }),
        if (_profileEffects.glowEnabled) _buildGlowIntensitySlider(),
        if (_profileEffects.glowEnabled) _buildGlowColorPicker(),
        
        const SizedBox(height: 24),
        
        // Border Section (Unlocks at Level 25)
        const Text(
          '🖼️ Border',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildPulseToggle(level),
        
        const SizedBox(height: 24),
        
        // Particles Section (Unlocks at Level 30)
        const Text(
          '🎆 Particles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildParticlesToggle(level),
        if (_profileEffects.particlesEnabled) ...[
          _buildParticleTypeSelector(level),
          _buildParticleDensitySlider(),
        ],
        
        const SizedBox(height: 24),
        
        // Level Badge Section (Unlocks at Level 35)
        const Text(
          '🏆 Level Badge',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildLevelBadgeSelection(level),
      ],
    );
  }

  Widget _buildLevelBadgeSelection(int level) {
    return Column(
      children: [
        // Default circle option
        _buildLevelBadgeOption('Default Circle', null, true, level),
        
        // Level 35 badges
        if (ProfileEffects.isLevelBadgeUnlocked('rotating_plain', level))
          _buildLevelBadgeOption('🔵 Rotating Plain', 'rotating_plain', true, level),
        if (ProfileEffects.isLevelBadgeUnlocked('dual_ring', level))
          _buildLevelBadgeOption('⭕ Dual Ring', 'dual_ring', true, level),
        
        // Level 60 badges
        if (ProfileEffects.isLevelBadgeUnlocked('rotating_circle', level))
          _buildLevelBadgeOption('🔄 Rotating Circle', 'rotating_circle', true, level),
        if (ProfileEffects.isLevelBadgeUnlocked('folding_cube', level))
          _buildLevelBadgeOption('📦 Folding Cube', 'folding_cube', true, level),
        
        // Level 80 badges
        if (ProfileEffects.isLevelBadgeUnlocked('double_bounce', level))
          _buildLevelBadgeOption('⚡ Double Bounce', 'double_bounce', true, level),
        if (ProfileEffects.isLevelBadgeUnlocked('cube_grid', level))
          _buildLevelBadgeOption('🔲 Cube Grid', 'cube_grid', true, level),
        
        // Locked badges
        if (!ProfileEffects.isLevelBadgeUnlocked('rotating_plain', level))
          _buildLevelBadgeOption('🔵 Rotating Plain', 'rotating_plain', false, level),
        if (!ProfileEffects.isLevelBadgeUnlocked('dual_ring', level))
          _buildLevelBadgeOption('⭕ Dual Ring', 'dual_ring', false, level),
        if (!ProfileEffects.isLevelBadgeUnlocked('rotating_circle', level))
          _buildLevelBadgeOption('🔄 Rotating Circle', 'rotating_circle', false, level),
        if (!ProfileEffects.isLevelBadgeUnlocked('folding_cube', level))
          _buildLevelBadgeOption('📦 Folding Cube', 'folding_cube', false, level),
        if (!ProfileEffects.isLevelBadgeUnlocked('double_bounce', level))
          _buildLevelBadgeOption('⚡ Double Bounce', 'double_bounce', false, level),
        if (!ProfileEffects.isLevelBadgeUnlocked('cube_grid', level))
          _buildLevelBadgeOption('🔲 Cube Grid', 'cube_grid', false, level),
      ],
    );
  }

  Widget _buildLevelBadgeOption(String name, String? badgeId, bool unlocked, int level) {
    final isSelected = _profileEffects.selectedLevelBadge == badgeId;
    
    String subtitle = '';
    if (!unlocked && badgeId != null) {
      int requiredLevel = 0;
      switch (badgeId) {
        case 'rotating_plain':
        case 'dual_ring':
          requiredLevel = 35;
          break;
        case 'rotating_circle':
        case 'folding_cube':
          requiredLevel = 60;
          break;
        case 'double_bounce':
        case 'cube_grid':
          requiredLevel = 80;
          break;
      }
      subtitle = 'Unlocks at Level $requiredLevel';
    }
    
    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: RadioListTile<String?>(
        title: Text(name),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
        value: badgeId,
        groupValue: _profileEffects.selectedLevelBadge,
        onChanged: unlocked ? (val) {
          setState(() {
            _profileEffects = _profileEffects.copyWith(selectedLevelBadge: val);
          });
        } : null,
      ),
    );
  }

  Widget _buildPatternOption(String name, String? patternId, bool unlocked) {
    final isSelected = _profileEffects.selectedPattern == patternId;
    
    String subtitle = '';
    if (!unlocked && patternId != null) {
      int requiredLevel = 0;
      switch (patternId) {
        case 'stripes': requiredLevel = 5; break;
        case 'dots': requiredLevel = 45; break;
        case 'waves': requiredLevel = 55; break;
        case 'hexagons': requiredLevel = 70; break;
      }
      subtitle = 'Unlocks at Level $requiredLevel';
    }
    
    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: RadioListTile<String?>(
        title: Text(name),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
        value: patternId,
        groupValue: _profileEffects.selectedPattern,
        onChanged: unlocked ? (val) {
          setState(() {
            // Explicitly handle null for "None" option
            if (val == null) {
              _profileEffects = ProfileEffects(
                selectedPattern: null,
                shimmerEnabled: _profileEffects.shimmerEnabled,
                animatedGradientEnabled: _profileEffects.animatedGradientEnabled,
                glowEnabled: _profileEffects.glowEnabled,
                glowIntensity: _profileEffects.glowIntensity,
                pulseEnabled: _profileEffects.pulseEnabled,
                pulseSpeed: _profileEffects.pulseSpeed,
                particlesEnabled: _profileEffects.particlesEnabled,
                particleType: _profileEffects.particleType,
                particleDensity: _profileEffects.particleDensity,
                particleColor: _profileEffects.particleColor,
              );
            } else {
              _profileEffects = _profileEffects.copyWith(selectedPattern: val);
            }
          });
        } : null,
      ),
    );
  }

  Widget _buildPulseToggle(int level) {
    final unlocked = ProfileEffects.isEffectUnlocked('pulse', level);
    
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Pulsing Effect'),
          subtitle: unlocked ? const Text('Gentle breathing animation') : const Text('Unlocks at Level 40', style: TextStyle(color: Colors.grey)),
          value: _profileEffects.pulseEnabled,
          onChanged: unlocked ? (val) {
            setState(() {
              _profileEffects = _profileEffects.copyWith(pulseEnabled: val);
            });
          } : null,
        ),
        if (unlocked && _profileEffects.pulseEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Speed:'),
                Expanded(
                  child: Slider(
                    value: _profileEffects.pulseSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${_profileEffects.pulseSpeed.toStringAsFixed(1)}x',
                    onChanged: (val) {
                      setState(() {
                        _profileEffects = _profileEffects.copyWith(pulseSpeed: val);
                      });
                    },
                  ),
                ),
                Text('${_profileEffects.pulseSpeed.toStringAsFixed(1)}x'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEffectToggle(String name, String effectId, int level, bool value, ValueChanged<bool> onChanged) {
    final unlocked = ProfileEffects.isEffectUnlocked(effectId, level);
    int requiredLevel = 0;
    
    switch (effectId) {
      case 'shimmer': requiredLevel = 20; break;
      case 'animatedGradient': requiredLevel = 30; break;
      case 'glow': requiredLevel = 35; break;
    }
    
    return SwitchListTile(
      title: Text(name),
      subtitle: unlocked ? null : Text('Unlocks at Level $requiredLevel', style: const TextStyle(color: Colors.grey)),
      value: value,
      onChanged: unlocked ? onChanged : null,
    );
  }

  Widget _buildGlowIntensitySlider() {
    // Clamp value to valid range (in case of old saved data)
    final clampedIntensity = _profileEffects.glowIntensity.clamp(0.5, 2.0);
    final displayPercent = (clampedIntensity * 100).round();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Glow Intensity: $displayPercent%'),
          Slider(
            value: clampedIntensity,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '$displayPercent%',
            onChanged: (val) {
              setState(() {
                _profileEffects = _profileEffects.copyWith(glowIntensity: val);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlowColorPicker() {
    final colors = [
      {'name': 'Amber', 'color': Colors.amber},
      {'name': 'Blue', 'color': Colors.blue},
      {'name': 'Purple', 'color': Colors.purple},
      {'name': 'Green', 'color': Colors.green},
      {'name': 'Red', 'color': Colors.red},
      {'name': 'Cyan', 'color': Colors.cyan},
      {'name': 'Pink', 'color': Colors.pink},
      {'name': 'White', 'color': Colors.white},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Glow Color:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((colorData) {
              final color = colorData['color'] as Color;
              final isSelected = _profileEffects.glowColor == color;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _profileEffects = _profileEffects.copyWith(glowColor: color);
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.black, size: 28)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildParticlesToggle(int level) {
    final unlocked = ProfileEffects.areParticlesUnlocked(level);
    
    return SwitchListTile(
      title: const Text('Particles'),
      subtitle: unlocked ? null : const Text('Unlocks at Level 50', style: TextStyle(color: Colors.grey)),
      value: _profileEffects.particlesEnabled,
      onChanged: unlocked ? (val) {
        setState(() {
          _profileEffects = _profileEffects.copyWith(particlesEnabled: val);
          // Set default particle type if none selected
          if (val && _profileEffects.particleType == null) {
            final availableTypes = ProfileEffects.getAvailableParticleTypes(level);
            if (availableTypes.isNotEmpty) {
              _profileEffects = _profileEffects.copyWith(particleType: availableTypes.first);
            }
          }
        });
      } : null,
    );
  }

  Widget _buildParticleTypeSelector(int level) {
    final availableTypes = ProfileEffects.getAvailableParticleTypes(level);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Particle Type:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...availableTypes.map((type) {
            String displayName = '';
            String levelInfo = '';
            switch (type) {
              case 'embers':
                displayName = '🔥 Embers';
                levelInfo = '(Level 50)';
                break;
              case 'fireflies':
                displayName = '✨ Fireflies';
                levelInfo = '(Level 55)';
                break;
              case 'stars':
                displayName = '⭐ Stars';
                levelInfo = '(Level 80)';
                break;
              case 'sparkles':
                displayName = '💫 Sparkles';
                levelInfo = '(Level 95)';
                break;
              case 'orbs':
                displayName = '🔮 Orbs';
                levelInfo = '(Level 95)';
                break;
            }
            
            return RadioListTile<String>(
              title: Text('$displayName $levelInfo'),
              value: type,
              groupValue: _profileEffects.particleType,
              onChanged: (val) {
                setState(() {
                  _profileEffects = _profileEffects.copyWith(particleType: val);
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildParticleDensitySlider() {
    // Clamp value to valid range (in case of old saved data)
    final clampedDensity = _profileEffects.particleDensity.clamp(0.5, 2.0);
    final displayPercent = (clampedDensity * 100).round();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Particle Density: $displayPercent%'),
          Slider(
            value: clampedDensity,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '$displayPercent%',
            onChanged: (val) {
              setState(() {
                _profileEffects = _profileEffects.copyWith(particleDensity: val);
              });
            },
          ),
        ],
      ),
    );
  }
}
