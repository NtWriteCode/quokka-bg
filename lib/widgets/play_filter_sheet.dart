import 'package:flutter/material.dart';
import 'package:quokka/models/play_filter.dart';
import 'package:quokka/models/board_game.dart';
import 'package:quokka/models/player.dart';
import 'package:quokka/repositories/game_repository.dart';

class PlayFilterSheet extends StatefulWidget {
  final GameRepository repository;
  final PlayFilter initialFilter;
  final ValueChanged<PlayFilter> onApply;

  const PlayFilterSheet({
    super.key,
    required this.repository,
    required this.initialFilter,
    required this.onApply,
  });

  @override
  State<PlayFilterSheet> createState() => _PlayFilterSheetState();
}

class _PlayFilterSheetState extends State<PlayFilterSheet> {
  late PlayFilter _filter;
  int _resetKey = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quick Filter',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() {
                    _filter = PlayFilter();
                    _resetKey++;
                  }),
                  child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24.0),
                children: [
                  // Game Filter
                  _buildSectionTitle('Game'),
                  Autocomplete<BoardGame>(
                    key: ValueKey(_resetKey),
                    initialValue: TextEditingValue(
                      text: _filter.gameId != null
                          ? widget.repository.ownedGames
                              .firstWhere((g) => g.id == _filter.gameId)
                              .name
                          : '',
                    ),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final games = widget.repository.ownedGames
                          .where((g) => g.status != GameStatus.wishlist)
                          .toList();
                      if (textEditingValue.text.isEmpty) {
                        return games;
                      }
                      return games.where((g) => g.name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (BoardGame option) => option.name,
                    onSelected: (BoardGame selection) {
                      setState(() =>
                          _filter = _filter.copyWith(gameId: () => selection.id));
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search or select game...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    controller.clear();
                                    setState(() => _filter =
                                        _filter.copyWith(gameId: () => null));
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 48,
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option.name),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Winner Filter
                  _buildSectionTitle('Winner'),
                  DropdownButtonFormField<String?>(
                    value: _filter.winnerId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Anyone')),
                      ...widget.repository.players.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          )),
                    ],
                    onChanged: (val) => setState(
                        () => _filter = _filter.copyWith(winnerId: () => val)),
                  ),
                  const SizedBox(height: 24),

                  // Participants Filter
                  _buildSectionTitle('Participants (Include)'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.repository.players.map((player) {
                      final isSelected = _filter.playerIds.contains(player.id);
                      return FilterChip(
                        label: Text(player.name),
                        selected: isSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (val) {
                          setState(() {
                            final newIds = List<String>.from(_filter.playerIds);
                            if (val) {
                              newIds.add(player.id);
                            } else {
                              newIds.remove(player.id);
                            }
                            _filter = _filter.copyWith(playerIds: newIds);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Date Filter
                  _buildSectionTitle('Date Range'),
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_filter.dateRange == null
                        ? 'Pick Date Range'
                        : '${_filter.dateRange!.start.year}-${_filter.dateRange!.start.month}-${_filter.dateRange!.start.day} to ${_filter.dateRange!.end.year}-${_filter.dateRange!.end.month}-${_filter.dateRange!.end.day}'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_filter);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Apply Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _filter.dateRange,
    );
    if (picked != null) {
      setState(() => _filter = _filter.copyWith(dateRange: () => picked));
    }
  }
}
