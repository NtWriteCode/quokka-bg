import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quokka/models/leaderboard_entry.dart';
import 'package:quokka/models/profile_effects.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/helpers/title_helper.dart';
import 'package:quokka/widgets/gradient_background.dart';
import 'package:quokka/widgets/pattern_overlay.dart';
import 'package:quokka/widgets/shimmer_effect.dart';
import 'package:quokka/widgets/animated_gradient_background.dart';
import 'package:quokka/widgets/particle_effect.dart';
import 'package:quokka/widgets/pulse_effect.dart';
import 'package:quokka/widgets/level_badge.dart';

enum LeaderboardCategory {
  level('Level', '🏆'),
  totalPlays('Total Plays', '🎲'),
  currentStreak('Current Play Streak', '🔥'),
  gamesOwned('Total Owned', '📚'),
  achievements('Achievements', '🎯'),
  longestStreak('Longest Play Streak', '🌟');

  final String label;
  final String emoji;
  const LeaderboardCategory(this.label, this.emoji);
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  bool _isEnabled = false;
  LeaderboardCategory _selectedCategory = LeaderboardCategory.level;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final repository = context.read<GameRepository>();
    
    // Check if leaderboard is enabled
    final enabled = await repository.isLeaderboardEnabled();
    
    if (!mounted) return;
    
    if (enabled) {
      final entries = await repository.downloadLeaderboard();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isEnabled = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isEnabled = false;
        _isLoading = false;
      });
    }
  }

  List<LeaderboardEntry> _getSortedEntries() {
    final sorted = List<LeaderboardEntry>.from(_entries);
    
    switch (_selectedCategory) {
      case LeaderboardCategory.level:
        sorted.sort((a, b) {
          final levelCompare = b.stats.level.compareTo(a.stats.level);
          if (levelCompare != 0) return levelCompare;
          return b.stats.totalXp.compareTo(a.stats.totalXp);
        });
        break;
      case LeaderboardCategory.totalPlays:
        sorted.sort((a, b) => b.stats.totalPlays.compareTo(a.stats.totalPlays));
        break;
      case LeaderboardCategory.currentStreak:
        sorted.sort((a, b) => b.stats.currentStreak.compareTo(a.stats.currentStreak));
        break;
      case LeaderboardCategory.gamesOwned:
        sorted.sort((a, b) => b.stats.gamesOwned.compareTo(a.stats.gamesOwned));
        break;
      case LeaderboardCategory.achievements:
        sorted.sort((a, b) => b.stats.achievementsUnlocked.compareTo(a.stats.achievementsUnlocked));
        break;
      case LeaderboardCategory.longestStreak:
        sorted.sort((a, b) => b.stats.longestStreak.compareTo(a.stats.longestStreak));
        break;
    }
    
    return sorted.take(10).toList();
  }

  Map<String, Set<String>> _calculateTopPlayers() {
    // Calculate who is #1 in each category
    final topPlayers = <String, Set<String>>{};
    
    for (final category in LeaderboardCategory.values) {
      final sorted = List<LeaderboardEntry>.from(_entries);
      
      switch (category) {
        case LeaderboardCategory.level:
          sorted.sort((a, b) {
            final levelCompare = b.stats.level.compareTo(a.stats.level);
            if (levelCompare != 0) return levelCompare;
            return b.stats.totalXp.compareTo(a.stats.totalXp);
          });
          break;
        case LeaderboardCategory.totalPlays:
          sorted.sort((a, b) => b.stats.totalPlays.compareTo(a.stats.totalPlays));
          break;
        case LeaderboardCategory.currentStreak:
          sorted.sort((a, b) => b.stats.currentStreak.compareTo(a.stats.currentStreak));
          break;
        case LeaderboardCategory.gamesOwned:
          sorted.sort((a, b) => b.stats.gamesOwned.compareTo(a.stats.gamesOwned));
          break;
        case LeaderboardCategory.achievements:
          sorted.sort((a, b) => b.stats.achievementsUnlocked.compareTo(a.stats.achievementsUnlocked));
          break;
        case LeaderboardCategory.longestStreak:
          sorted.sort((a, b) => b.stats.longestStreak.compareTo(a.stats.longestStreak));
          break;
      }
      
      if (sorted.isNotEmpty) {
        final topUserId = sorted.first.userId;
        topPlayers.putIfAbsent(topUserId, () => {});
        topPlayers[topUserId]!.add(category.emoji);
      }
    }
    
    return topPlayers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isEnabled
              ? _buildDisabledView()
              : _buildLeaderboardView(),
    );
  }

  Widget _buildDisabledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Leaderboard Not Available',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The leaderboard feature is not enabled on your sync server. '
              'To enable it, create a "global_shared/quokka_bg" folder on your WebDAV server.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardView() {
    final sortedEntries = _getSortedEntries();
    final topPlayers = _calculateTopPlayers();
    final repository = context.read<GameRepository>();
    final currentUserId = repository.userStats.userId;

    return Column(
      children: [
        // Category selector - Horizontal scrollable chips
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: LeaderboardCategory.values.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text('${category.emoji} ${category.label}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        // Leaderboard list
        Expanded(
          child: sortedEntries.isEmpty
              ? Center(
                  child: Text(
                    'No players yet. Be the first!',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = sortedEntries[index];
                    final isCurrentUser = entry.userId == currentUserId;
                    final userTopCategories = topPlayers[entry.userId] ?? {};
                    
                    return _buildLeaderboardCard(
                      context,
                      rank: index + 1,
                      entry: entry,
                      isCurrentUser: isCurrentUser,
                      topCategories: userTopCategories,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard(
    BuildContext context, {
    required int rank,
    required LeaderboardEntry entry,
    required bool isCurrentUser,
    required Set<String> topCategories,
  }) {
    final tier = entry.customBackgroundTier ?? (entry.stats.level / 5).floor();
    final gradient = TitleHelper.getBackgroundForLevel(tier * 5);
    final title = entry.achievementTitleName; // Can be null if no achievement title selected

    // Rank medal
    String rankDisplay = '$rank';
    Color? rankColor;
    if (rank == 1) {
      rankDisplay = '🥇';
    } else if (rank == 2) {
      rankDisplay = '🥈';
    } else if (rank == 3) {
      rankDisplay = '🥉';
    }

    // Get profile effects for glow
    final effects = entry.profileEffects ?? const ProfileEffects();
    final glowColor = effects.glowColor ?? Colors.amber;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => _showUserDetailsDialog(context, entry, rank, isCurrentUser, topCategories),
        child: Container(
          decoration: effects.glowEnabled ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
          ) : null,
          child: PulseEffect(
            enabled: effects.pulseEnabled,
            speed: effects.pulseSpeed,
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
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: isCurrentUser
                                ? Border.all(color: Colors.amber, width: 3)
                                : null,
                          ),
                          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 40,
                    child: Text(
                      rankDisplay,
                      style: TextStyle(
                        fontSize: rank <= 3 ? 28 : 20,
                        fontWeight: FontWeight.bold,
                        color: rankColor ?? Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (title != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (topCategories.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: topCategories.map((emoji) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#1 $emoji',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Level badge
                  LevelBadge(
                    level: entry.stats.level,
                    badgeType: effects.selectedLevelBadge,
                    size: 60,
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
            ),
          ),
    );
  }

  void _showUserDetailsDialog(
    BuildContext context,
    LeaderboardEntry entry,
    int rank,
    bool isCurrentUser,
    Set<String> topCategories,
  ) {
    final tier = entry.customBackgroundTier ?? (entry.stats.level / 5).floor();
    final gradient = TitleHelper.getBackgroundForLevel(tier * 5);
    final title = entry.achievementTitleName; // Can be null if no achievement title selected
    final backgroundTierName = TitleHelper.getTierNameForLevel(tier * 5);

    // Rank display
    String rankDisplay = '#$rank';
    if (rank == 1) {
      rankDisplay = '🥇 #1';
    } else if (rank == 2) rankDisplay = '🥈 #2';
    else if (rank == 3) rankDisplay = '🥉 #3';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient background
              GradientBackground(
                gradient: gradient,
                tier: tier,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.displayName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (title != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Level ${entry.stats.level}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            rankDisplay,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Background: $backgroundTierName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Stats section
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top achievements badges
                      if (topCategories.isNotEmpty) ...[
                        const Text(
                          'Top Achievements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topCategories.map((emoji) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '#1 $emoji',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const Divider(height: 32),
                      ],
                      
                      // Detailed stats
                      const Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(context, '🏆', 'Level', entry.stats.level.toString()),
                      _buildStatRow(context, '⭐', 'Total XP', entry.stats.totalXp.round().toString()),
                      _buildStatRow(context, '🎲', 'Total Plays', entry.stats.totalPlays.toString()),
                      _buildStatRow(context, '🎮', 'Unique Games Played', entry.stats.uniqueGamesPlayed.toString()),
                      _buildStatRow(context, '📚', 'Total Owned (incl. lended)', entry.stats.gamesOwned.toString()),
                      _buildStatRow(context, '🎯', 'Achievements Unlocked', entry.stats.achievementsUnlocked.toString()),
                      _buildStatRow(context, '🔥', 'Current Play Streak', '${entry.stats.currentStreak} days'),
                      _buildStatRow(context, '🌟', 'Longest Play Streak', '${entry.stats.longestStreak} days'),
                      
                      const Divider(height: 32),
                      
                      // Last updated
                      Text(
                        'Last updated: ${_formatDate(entry.lastUpdated)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Close button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
