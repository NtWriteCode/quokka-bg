import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quokka/models/board_game.dart';
import 'package:quokka/services/image_cache_manager.dart';
import 'package:quokka/pages/add_game_page.dart';
import 'package:quokka/pages/verify_game_page.dart';
import 'package:quokka/repositories/game_repository.dart';

enum SortMode { name, dateAdded, playCount }

class GamesListPage extends StatefulWidget {
  final GameRepository repository;
  final bool isWishlist;
  final String title;

  final bool showAppBar;
  final bool showFloatingActionButton;
  final String? externalSearchQuery;
  final SortMode? externalSortMode;

  const GamesListPage({
    super.key,
    required this.repository,
    this.isWishlist = false,
    required this.title,
    this.showAppBar = true,
    this.showFloatingActionButton = true,
    this.externalSearchQuery,
    this.externalSortMode,
  });

  @override
  State<GamesListPage> createState() => _GamesListPageState();
}

class _GamesListPageState extends State<GamesListPage> {
  bool _isLoading = true;
  bool _isSearchMode = false;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.name;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
    _loadGames();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadGames() async {
    await widget.repository.loadGames();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentSearchQuery = widget.externalSearchQuery ?? _searchQuery;
    final SortMode currentSortMode = widget.externalSortMode ?? _sortMode;

    List<BoardGame> gamesList = widget.isWishlist
        ? widget.repository.ownedGames.where((g) => g.status == GameStatus.wishlist).toList()
        : widget.repository.ownedGames.where((g) => g.status != GameStatus.wishlist).toList();

    // 1. Filter by Search Query
    if (currentSearchQuery.isNotEmpty) {
      gamesList = gamesList.where((g) => g.name.toLowerCase().contains(currentSearchQuery.toLowerCase())).toList();
    }

    // 2. Initial Sort (Main Sort Mode)
    _sortGames(gamesList, currentSortMode);

    // Sorting and grouping for collection only
    final List<Widget> children = [];
    if (!widget.isWishlist) {
      final owned = gamesList.where((g) => g.status == GameStatus.owned).toList();
      final lended = gamesList.where((g) => g.status == GameStatus.lended).toList();
      final sold = gamesList.where((g) => g.status == GameStatus.sold).toList();
      final unowned = gamesList.where((g) => g.status == GameStatus.unowned).toList();

      if (owned.isNotEmpty) children.addAll(_buildSection('Owned', owned));
      if (lended.isNotEmpty) children.addAll(_buildSection('Lended', lended));
      if (sold.isNotEmpty) children.addAll(_buildSection('Sold', sold));
      if (unowned.isNotEmpty && widget.repository.showUnownedGames) {
        children.addAll(_buildSection('Other (Not Owned)', unowned));
      }
    } else {
      final sortedWishlist = _sortGamesWithExpansions(gamesList);
      children.addAll(sortedWishlist.map((g) => _buildGameTile(g)));
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: _isSearchMode
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search collection...',
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    )
                  : Text(widget.title),
              actions: [
                IconButton(
                  icon: Icon(_isSearchMode ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearchMode = !_isSearchMode;
                      if (!_isSearchMode) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
                PopupMenuButton<SortMode>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort By',
                  onSelected: (mode) => setState(() => _sortMode = mode),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: SortMode.name,
                        child: Text('A-Z (Name)',
                            style: TextStyle(fontWeight: currentSortMode == SortMode.name ? FontWeight.bold : FontWeight.normal))),
                    PopupMenuItem(
                        value: SortMode.dateAdded,
                        child: Text('Newest First',
                            style: TextStyle(fontWeight: currentSortMode == SortMode.dateAdded ? FontWeight.bold : FontWeight.normal))),
                    PopupMenuItem(
                        value: SortMode.playCount,
                        child: Text('Most Played',
                            style: TextStyle(fontWeight: currentSortMode == SortMode.playCount ? FontWeight.bold : FontWeight.normal))),
                  ],
                ),
              ],
            )
          : null,
      floatingActionButton: widget.showFloatingActionButton
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddGamePage(
                            repository: widget.repository,
                            isWishlist: widget.isWishlist,
                          )),
                );
                if (result == true) {
                  _loadGames();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : gamesList.isEmpty
              ? Center(child: Text(widget.isWishlist ? 'Wishlist is empty.' : 'No games yet. Add one!'))
              : ListView(children: children),
    );
  }

  List<Widget> _buildSection(String title, List<BoardGame> games) {
    final sortedGames = _sortGamesWithExpansions(games);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      ...sortedGames.map((game) => _buildGameTile(game, sortedGames)),
    ];
  }

  void _sortGames(List<BoardGame> games, SortMode mode) {
    switch (mode) {
      case SortMode.name:
        games.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortMode.dateAdded:
        games.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortMode.playCount:
        games.sort((a, b) {
          final countA = widget.repository.getPlayCountForGame(a.id);
          final countB = widget.repository.getPlayCountForGame(b.id);
          return countB.compareTo(countA);
        });
        break;
    }
  }

  List<BoardGame> _sortGamesWithExpansions(List<BoardGame> games) {
    final SortMode currentSortMode = widget.externalSortMode ?? _sortMode;

    // 1. Separate into "Roots" and "Children"
    // A Root is any base game, OR an expansion whose parent is NOT in the current list
    final rootItems = games.where((g) {
      if (!g.isExpansion) return true;
      return !games.any((other) => other.id == g.parentGameId);
    }).toList();
    _sortGames(rootItems, currentSortMode);

    final children = games.where((g) => g.isExpansion && games.any((other) => other.id == g.parentGameId)).toList();
    
    final List<BoardGame> result = [];
    
    // 2. Interleave
    for (var root in rootItems) {
      result.add(root);
      final relatedChildren = children.where((e) => e.parentGameId == root.id).toList();
      if (relatedChildren.isNotEmpty) {
        _sortGames(relatedChildren, currentSortMode);
        result.addAll(relatedChildren);
      }
    }
    
    return result;
  }

  Widget _buildGameTile(BoardGame game, List<BoardGame> currentList) {
    // An expansion is indented ONLY if its parent is actually in the list we are looking at
    final bool shouldIndent = game.isExpansion && currentList.any((g) => g.id == game.parentGameId);

    return ListTile(
      leading: game.customThumbnailUrl != null
          ? CachedNetworkImage(
              imageUrl: game.customThumbnailUrl!,
              width: 50,
              cacheManager: QuokkaCacheManager.instance,
              placeholder: (context, url) => Container(width: 50, color: Colors.grey[200]),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            )
          : const Icon(Icons.videogame_asset),
      title: Row(
        children: [
          if (shouldIndent)
            const Padding(
              padding: EdgeInsets.only(right: 4.0),
              child: Text('↳', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          Expanded(child: Text(game.name, style: TextStyle(fontSize: shouldIndent ? 14 : 16))),
        ],
      ),
      contentPadding: EdgeInsets.only(left: shouldIndent ? 32.0 : 16.0, right: 16.0),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${game.yearPublished} • ${game.minPlayers}-${game.maxPlayers} players'),
          if (!widget.isWishlist)
            Text(
              'Played ${widget.repository.getPlayCountForGame(game.id)} times',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyGamePage(
              existingGame: game,
              repository: widget.repository,
            ),
          ),
        );
        _loadGames();
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isWishlist)
            PopupMenuButton<GameStatus>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Change Status',
              onSelected: (status) async {
                await widget.repository.updateGameStatus(game.id, status);
                _loadGames();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: GameStatus.owned, child: Text('Move to Owned')),
                const PopupMenuItem(value: GameStatus.lended, child: Text('Move to Lended')),
                const PopupMenuItem(value: GameStatus.sold, child: Text('Move to Sold')),
                const PopupMenuItem(value: GameStatus.unowned, child: Text('Move to Not Owned')),
              ],
            ),
          if (widget.isWishlist)
            IconButton(
              icon: const Icon(Icons.shopping_cart_checkout, color: Colors.green),
              tooltip: 'Move to Collection',
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VerifyGamePage(
                      repository: widget.repository,
                      existingGame: game,
                      isWishlist: false,
                    ),
                  ),
                );
                if (result == true) {
                  _loadGames();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.grey),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: const Text('Delete Game'),
                        content: Text('Are you sure you want to remove ${game.name} from your ${widget.isWishlist ? "wishlist" : "collection"}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ));
              if (confirmed == true) {
                await widget.repository.removeGame(game.id);
                _loadGames();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    _searchController.dispose();
    super.dispose();
  }
}
