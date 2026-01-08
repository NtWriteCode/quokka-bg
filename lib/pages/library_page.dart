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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
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
          ),
          GamesListPage(
            repository: widget.repository,
            isWishlist: true,
            title: 'Wishlist',
            showAppBar: false,
            showFloatingActionButton: false,
          ),
        ],
      ),
    );
  }
}
