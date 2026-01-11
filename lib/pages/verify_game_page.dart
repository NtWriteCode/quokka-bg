import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:quokka/models/board_game.dart';
import 'package:quokka/services/image_cache_manager.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:html_unescape/html_unescape.dart';

class VerifyGamePage extends StatefulWidget {
  final Map<String, dynamic>? searchResult;
  final BoardGame? existingGame;
  final GameRepository repository;
  final bool isWishlist;

  const VerifyGamePage({
    super.key,
    this.searchResult,
    this.existingGame,
    required this.repository,
    this.isWishlist = false,
  }) : assert(searchResult != null || existingGame != null);

  @override
  State<VerifyGamePage> createState() => _VerifyGamePageState();
}

class _VerifyGamePageState extends State<VerifyGamePage> {
  bool _isLoading = true;
  BoardGame? _gameDetails;
  String? _errorMessage;
  String? _selectedTitle;
  String? _searchTitle;
  String? _detailTitle;

  // Input controllers
  final _priceController = TextEditingController();
  final _commentController = TextEditingController();
  String _selectedCurrency = 'HUF';
  bool _isNew = true;
  DateTime? _purchaseDate;
  bool _isExpansion = false;
  String? _parentGameId;

  final List<String> _currencies = ['HUF', 'USD', 'EUR'];

  @override
  void initState() {
    super.initState();
    if (widget.existingGame != null) {
      _gameDetails = widget.existingGame;
      _selectedTitle = _gameDetails!.name;
      _isLoading = false;
      // Initialize inputs from existing game
      _priceController.text = _gameDetails!.price?.toString() ?? '';
      _commentController.text = _gameDetails!.comment ?? '';
      _selectedCurrency = _gameDetails!.currency ?? 'HUF';
      _isNew = _gameDetails!.isNew ?? true;
      _purchaseDate = _gameDetails!.purchaseDate;
      _isExpansion = _gameDetails!.isExpansion;
      _parentGameId = _gameDetails!.parentGameId;
    } else {
      _searchTitle = widget.searchResult!['localizedname'] ?? widget.searchResult!['name'];
      _loadDetails();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final gameId = widget.searchResult!['id']?.toString();
    if (gameId != null) {
      final detailsMap = await widget.repository.fetchGameDetails(gameId);
      if (mounted) {
        if (detailsMap != null) {
          final details = widget.repository.convertDetailsToLocal(detailsMap);
          final item = detailsMap['item'];
          final detailLocalized = item?['localizedname'];
          
          setState(() {
            _gameDetails = details;
            _detailTitle = details?.name;
            if (detailLocalized != null && detailLocalized != _detailTitle) {
              _searchTitle = detailLocalized;
            }
            // Default to search title (localized), but keep detail title for choice if different
            _selectedTitle = _searchTitle ?? _detailTitle;
            _isExpansion = details?.isExpansion ?? false;
            _parentGameId = details?.parentGameId;
            _isLoading = false;
          });
        } else {
          setState(() {
            _gameDetails = widget.repository.convertToLocal(
              searchResult: widget.searchResult!,
              imageUrl: null,
              thumbnailUrl: null,
            );
            _selectedTitle = _searchTitle;
            _errorMessage = "Could not fetch full details, adding with basic info.";
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedTitle = _searchTitle;
          _isLoading = false;
        });
      }
    }
  }

  void _addGame() async {
    if (_gameDetails != null) {
      // Check if game already exists in collection/wishlist
      final alreadyExists = widget.repository.ownedGames.any((g) => g.id == _gameDetails!.id);
      if (alreadyExists && widget.existingGame == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This game is already in your collection or wishlist!'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final double? price = double.tryParse(_priceController.text);
      
      // Create a final version of the game with the purchase details
      final finalGame = BoardGame(
        id: _gameDetails!.id,
        name: _selectedTitle ?? _gameDetails!.name,
        description: _gameDetails!.description,
        yearPublished: _gameDetails!.yearPublished,
        minPlayers: _gameDetails!.minPlayers,
        maxPlayers: _gameDetails!.maxPlayers,
        playingTime: _gameDetails!.playingTime,
        minPlayTime: _gameDetails!.minPlayTime,
        maxPlayTime: _gameDetails!.maxPlayTime,
        minAge: _gameDetails!.minAge,
        averageRating: _gameDetails!.averageRating,
        averageWeight: _gameDetails!.averageWeight,
        customImageUrl: _gameDetails!.customImageUrl,
        customThumbnailUrl: _gameDetails!.customThumbnailUrl,
        dateAdded: _gameDetails!.dateAdded,
        // Purchase details
        price: price,
        currency: _selectedCurrency,
        isNew: _isNew,
        purchaseDate: _purchaseDate,
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
        status: widget.isWishlist ? GameStatus.wishlist : GameStatus.owned,
        isExpansion: _isExpansion,
        parentGameId: _parentGameId,
      );

      if (widget.existingGame != null) {
        await widget.repository.updateGame(finalGame);
      } else {
        await widget.repository.addGame(finalGame);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingGame != null && widget.existingGame!.isWishlist && !finalGame.isWishlist
                  ? 'Moved ${finalGame.name} to Collection!'
                  : 'Saved ${finalGame.name}',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _stripHtml(String text) {
    final unescape = HtmlUnescape();
    final stripped = text.replaceAll(RegExp(r'<[^>]*>'), '');
    return unescape.convert(stripped);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConversion = widget.existingGame != null && 
                        widget.existingGame!.isWishlist && 
                        !widget.isWishlist;
    final isViewMode = widget.existingGame != null && !isConversion;
    
    final game = _gameDetails;
    // Show purchase section if we are NOT adding to wishlist AND (it's a new game OR it's a conversion OR it's already owned)
    final showPurchaseSection = !widget.isWishlist && (widget.existingGame != null ? (game?.status != GameStatus.wishlist || isConversion) : true);
    
    final name = game?.name ?? widget.searchResult?['name'] ?? 'Unknown';
    final year = game?.yearPublished?.toString() ?? widget.searchResult?['yearpublished']?.toString() ?? '?';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isConversion 
            ? 'Move to Collection' 
            : (isViewMode ? 'Game Details' : (widget.isWishlist ? 'Add to Wishlist' : 'Verify Game Details'))
        )
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Card(
                      color: Colors.orange[100],
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.brown)),
                      ),
                    ),
                  
                  // Duplicate warning
                  if (widget.existingGame == null && widget.repository.ownedGames.any((g) => g.id == _gameDetails?.id))
                    Card(
                      color: Colors.red[50],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.red.shade200)),
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Duplicate: This game is already in your list.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (game?.customImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: game!.customImageUrl!,
                      height: 300,
                      fit: BoxFit.contain,
                      cacheManager: QuokkaCacheManager.instance,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 100),
                    )
                  else
                    const Icon(Icons.image_not_supported, size: 100),
                  
                  const SizedBox(height: 24),
                  Text(
                    _selectedTitle ?? name,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Published: $year',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (!isViewMode)
                    SwitchListTile(
                      title: const Text('Is Expansion?'),
                      subtitle: const Text('Check this if this game is an expansion for another game'),
                      value: _isExpansion,
                      onChanged: (val) => setState(() => _isExpansion = val),
                    ),
                  if (isViewMode && _isExpansion)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.extension, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text('This is an expansion', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Title selection if names differ
                  if (!isViewMode && _searchTitle != null && _detailTitle != null && _searchTitle != _detailTitle) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.translate, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Select Preferred Title', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<String>(
                            title: Text(_searchTitle!),
                            subtitle: const Text('From your search (e.g. Hungarian)', style: TextStyle(fontSize: 12)),
                            value: _searchTitle!,
                            groupValue: _selectedTitle,
                            onChanged: (val) => setState(() => _selectedTitle = val),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: Text(_detailTitle!),
                            subtitle: const Text('From BGG database (International)', style: TextStyle(fontSize: 12)),
                            value: _detailTitle!,
                            groupValue: _selectedTitle,
                            onChanged: (val) => setState(() => _selectedTitle = val),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (game != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (game.averageRating != null)
                          Column(children: [
                            const Icon(Icons.star, color: Colors.amber),
                            Text('${game.averageRating!.toStringAsFixed(1)} / 10', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Rating', style: TextStyle(fontSize: 12)),
                          ]),
                        if (game.averageWeight != null)
                          Column(children: [
                            const Icon(Icons.line_weight, color: Colors.blueGrey),
                            Text('${game.averageWeight!.toStringAsFixed(2)} / 5', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Complexity', style: TextStyle(fontSize: 12)),
                          ]),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(Icons.group, 'Players', '${game.minPlayers ?? "?"} - ${game.maxPlayers ?? "?"}'),
                    _buildInfoRow(Icons.access_time, 'Play Time', '${game.minPlayTime ?? "?"} - ${game.maxPlayTime ?? "?"} min'),
                    _buildInfoRow(Icons.cake, 'Age', '${game.minAge ?? "?"}+'),
                    
                    if (showPurchaseSection) ...[
                      const Divider(height: 32),
                      const Text('Purchase Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      
                      if (!isViewMode) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _priceController,
                              decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()),
                              items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) => setState(() => _selectedCurrency = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Condition: '),
                          ChoiceChip(
                            label: const Text('New'),
                            selected: _isNew,
                            onSelected: (val) => setState(() => _isNew = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Used'),
                            selected: !_isNew,
                            onSelected: (val) => setState(() => _isNew = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_purchaseDate == null ? 'Select Purchase Date' : 'Purchased: ${_purchaseDate!.year}-${_purchaseDate!.month}-${_purchaseDate!.day}'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(labelText: 'Comment', border: OutlineInputBorder()),
                        maxLines: 3,
                      ),
                    ] else ...[
                      if (game.price != null) _buildInfoRow(Icons.payments, 'Price', '${game.price} ${game.currency}'),
                      _buildInfoRow(Icons.info_outline, 'Condition', game.isNew == true ? 'New' : 'Used'),
                      _buildInfoRow(Icons.label_important, 'Status', game.status.name.toUpperCase()),
                      if (game.purchaseDate != null) _buildInfoRow(Icons.calendar_today, 'Purchase Date', '${game.purchaseDate!.year}-${game.purchaseDate!.month}-${game.purchaseDate!.day}'),
                      if (game.comment != null) _buildInfoRow(Icons.comment, 'Comment', game.comment!),
                    ],
                  ],

                    if (game.description != null) ...[
                      const Divider(height: 32),
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(_stripHtml(game.description!), style: const TextStyle(height: 1.4)),
                    ],
                  ],
                  if (!isViewMode) ...[
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _addGame,
                      icon: const Icon(Icons.check),
                      label: Text(isConversion ? 'Confirm Purchase and Move' : 'Confirm and Add to Collection'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
