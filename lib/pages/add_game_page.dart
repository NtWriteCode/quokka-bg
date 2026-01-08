
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/pages/verify_game_page.dart';
import 'package:flutter/material.dart';

class AddGamePage extends StatefulWidget {
  final GameRepository repository;
  final bool isWishlist;

  const AddGamePage({
    super.key,
    required this.repository,
    this.isWishlist = false,
  });

  @override
  State<AddGamePage> createState() => _AddGamePageState();
}

class _AddGamePageState extends State<AddGamePage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final results = await widget.repository.searchBgg(_searchController.text);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _onGameSelected(Map<String, dynamic> searchResult) async {
    final bool? added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyGamePage(
          searchResult: searchResult,
          repository: widget.repository,
          isWishlist: widget.isWishlist,
        ),
      ),
    );

    if (added == true && mounted) {
      Navigator.pop(context, true); // Return to OwnedGamesPage
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isWishlist ? 'Add to Wishlist' : 'Add Game')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search BGG',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                final name = result['name'] ?? 'Unknown';
                final year = result['yearpublished']?.toString() ?? '?';
                return ListTile(
                  title: Text(name),
                  subtitle: Text('Year: $year'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _onGameSelected(result),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
