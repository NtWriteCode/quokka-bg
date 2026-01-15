import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quokka/models/leaderboard_entry.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/helpers/title_helper.dart';
import 'package:quokka/widgets/gradient_background.dart';

enum LeaderboardCategory {
  level('Level', '🏆'),
  totalPlays('Total Plays', '🎲'),
  currentStreak('Current Streak', '🔥'),
  gamesOwned('Games Owned', '📚'),
  achievements('Achievements', '🎯'),
  longestStreak('Longest Streak', '🌟');

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
    setState(() => _isLoading = true);
    
    final repository = context.read<GameRepository>();
    
    // Check if leaderboard is enabled
    final enabled = await repository.isLeaderboardEnabled();
    
    if (enabled) {
      final entries = await repository.downloadLeaderboard();
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

  int _getStatValue(LeaderboardEntry entry) {
    switch (_selectedCategory) {
      case LeaderboardCategory.level:
        return entry.stats.level;
      case LeaderboardCategory.totalPlays:
        return entry.stats.totalPlays;
      case LeaderboardCategory.currentStreak:
        return entry.stats.currentStreak;
      case LeaderboardCategory.gamesOwned:
        return entry.stats.gamesOwned;
      case LeaderboardCategory.achievements:
        return entry.stats.achievementsUnlocked;
      case LeaderboardCategory.longestStreak:
        return entry.stats.longestStreak;
    }
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
        // Category selector
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<LeaderboardCategory>(
            segments: LeaderboardCategory.values.map((category) {
              return ButtonSegment(
                value: category,
                label: Text('${category.emoji} ${category.label}'),
              );
            }).toList(),
            selected: {_selectedCategory},
            onSelectionChanged: (Set<LeaderboardCategory> selected) {
              setState(() {
                _selectedCategory = selected.first;
              });
            },
            showSelectedIcon: false,
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
    final title = entry.customTitle ?? TitleHelper.getTitleForLevel(entry.stats.level);
    final statValue = _getStatValue(entry);

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
                
                // Stat value
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statValue.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Level ${entry.stats.level}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
