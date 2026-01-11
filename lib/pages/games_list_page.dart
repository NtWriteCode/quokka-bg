import 'package:flutter/material.dart';
import 'package:quokka/models/board_game.dart';
import 'package:quokka/pages/add_game_page.dart';
import 'package:quokka/pages/verify_game_page.dart';
import 'package:quokka/repositories/game_repository.dart';

class GamesListPage extends StatefulWidget {
  final GameRepository repository;
  final bool isWishlist;
  final String title;

  final bool showAppBar;
  final bool showFloatingActionButton;

  const GamesListPage({
    super.key,
    required this.repository,
    this.isWishlist = false,
    required this.title,
    this.showAppBar = true,
    this.showFloatingActionButton = true,
  });

  @override
  State<GamesListPage> createState() => _GamesListPageState();
}

class _GamesListPageState extends State<GamesListPage> {
  bool _isLoading = true;

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
    final List<BoardGame> gamesList = widget.isWishlist
        ? widget.repository.ownedGames.where((g) => g.status == GameStatus.wishlist).toList()
        : widget.repository.ownedGames.where((g) => g.status != GameStatus.wishlist).toList();

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
      appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
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
      ...sortedGames.map((game) => _buildGameTile(game)),
    ];
  }

  List<BoardGame> _sortGamesWithExpansions(List<BoardGame> games) {
    // 1. Separate base games and expansions
    final baseGames = games.where((g) => !g.isExpansion).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    final expansions = games.where((g) => g.isExpansion).toList();
    
    final List<BoardGame> result = [];
    
    // 2. Put expansions after their parents
    for (var base in baseGames) {
      result.add(base);
      final relatedExpansions = expansions.where((e) => e.parentGameId == base.id).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      result.addAll(relatedExpansions);
    }
    
    // 3. Add orphaned expansions at the end
    final addedIds = result.map((g) => g.id).toSet();
    final orphans = expansions.where((e) => !addedIds.contains(e.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    result.addAll(orphans);
    
    return result;
  }

  Widget _buildGameTile(BoardGame game) {
    return ListTile(
      leading: game.customThumbnailUrl != null
          ? Image.network(game.customThumbnailUrl!,
              width: 50, errorBuilder: (_, __, ___) => const Icon(Icons.image))
          : const Icon(Icons.videogame_asset),
      title: Row(
        children: [
          if (game.isExpansion)
            const Padding(
              padding: EdgeInsets.only(right: 4.0),
              child: Text('↳', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          Expanded(child: Text(game.name, style: TextStyle(fontSize: game.isExpansion ? 14 : 16))),
        ],
      ),
      contentPadding: EdgeInsets.only(left: game.isExpansion ? 32.0 : 16.0, right: 16.0),
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
    super.dispose();
  }
}
