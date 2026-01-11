import 'package:flutter/material.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/pages/games_list_page.dart';
import 'package:quokka/pages/add_game_page.dart';

class LibraryPage extends StatefulWidget {
  final GameRepository repository;
  const LibraryPage({super.key, required this.repository});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearchMode = false;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.name;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchMode
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ${_tabController.index == 0 ? "collection" : "wishlist"}...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Text('My Library'),
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
                      style: TextStyle(fontWeight: _sortMode == SortMode.name ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(
                  value: SortMode.dateAdded,
                  child: Text('Newest First',
                      style: TextStyle(fontWeight: _sortMode == SortMode.dateAdded ? FontWeight.bold : FontWeight.normal))),
              PopupMenuItem(
                  value: SortMode.playCount,
                  child: Text('Most Played',
                      style: TextStyle(fontWeight: _sortMode == SortMode.playCount ? FontWeight.bold : FontWeight.normal))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Collection', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Wishlist', icon: Icon(Icons.favorite_outline)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final isWishlist = _tabController.index == 1;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddGamePage(
                repository: widget.repository,
                isWishlist: isWishlist,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          GamesListPage(
            repository: widget.repository,
            isWishlist: false,
            title: 'Collection',
            showAppBar: false,
            showFloatingActionButton: false,
            externalSearchQuery: _searchQuery,
            externalSortMode: _sortMode,
          ),
          GamesListPage(
            repository: widget.repository,
            isWishlist: true,
            title: 'Wishlist',
            showAppBar: false,
            showFloatingActionButton: false,
            externalSearchQuery: _searchQuery,
            externalSortMode: _sortMode,
          ),
        ],
      ),
    );
  }
}
