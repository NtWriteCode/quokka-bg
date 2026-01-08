import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bg_tracker/helpers/stats_helper.dart';
import 'package:bg_tracker/repositories/game_repository.dart';

class StatsPage extends StatefulWidget {
  final GameRepository repository;

  const StatsPage({super.key, required this.repository});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPeriod _selectedPeriod = StatsPeriod.year;

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

  @override
  Widget build(BuildContext context) {
    final helper = StatsHelper(
      games: widget.repository.ownedGames,
      plays: widget.repository.playRecords,
      players: widget.repository.players,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _PeriodSelector(
              selected: _selectedPeriod,
              onChanged: (p) => setState(() => _selectedPeriod = p),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Section
            _buildSectionTitle('Overview'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2,
              children: [
                _StatCard(label: 'Owned', value: helper.ownedCount.toString(), color: Colors.blue),
                _StatCard(label: 'Wishlist', value: helper.wishlistCount.toString(), color: Colors.pink),
                _StatCard(label: 'Lended', value: helper.lendedCount.toString(), color: Colors.cyan),
                _StatCard(label: 'Sold', value: helper.soldCount.toString(), color: Colors.orange),
                _StatCard(label: 'Other (Unowned)', value: helper.unownedCount.toString(), color: Colors.purple),
                _StatCard(
                  label: 'Plays (${_selectedPeriod.name})',
                  value: helper.getPlaysInPeriod(_selectedPeriod).length.toString(),
                  color: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Monthly Plays Chart
            _buildSectionTitle('Monthly Plays (Last 12 Months)'),
            SizedBox(
              height: 200,
              child: _MonthlyPlaysChart(data: helper.getMonthlyPlayCounts()),
            ),

            const SizedBox(height: 32),

            // Top Winners Chart
            _buildSectionTitle('Top Winners (${_selectedPeriod.name})'),
            SizedBox(
              height: 250,
              child: _TopWinnersChart(data: helper.getTopWinners(_selectedPeriod)),
            ),

            const SizedBox(height: 32),

            // Game Popularity
            _buildSectionTitle('Most Played Games'),
            _buildRankedList(helper.getMostPlayedGames(limit: 5), Icons.trending_up, Colors.orange),

            const SizedBox(height: 24),

            _buildSectionTitle('Least Played (Owned)'),
            _buildRankedList(helper.getLeastPlayedGames(limit: 5), Icons.trending_down, Colors.blueGrey),

            const SizedBox(height: 32),

            // Player Strengths
            _buildSectionTitle('Player Strongest Game'),
            _buildStrengthsList(helper.getPlayerStrongestGames()),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRankedList(List<MapEntry<String, int>> data, IconData icon, Color color) {
    if (data.isEmpty) return const Text('No data yet');
    return Column(
      children: data.map((e) => Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(e.key),
          trailing: Text('${e.value} plays', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      )).toList(),
    );
  }

  Widget _buildStrengthsList(Map<String, String> data) {
    if (data.isEmpty) return const Text('No data yet');
    return Column(
      children: data.entries.map((e) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Best at: ${e.value}'),
          trailing: const Icon(Icons.emoji_events, color: Colors.amber),
        ),
      )).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<StatsPeriod>(
      segments: const [
        ButtonSegment(value: StatsPeriod.week, label: Text('Week')),
        ButtonSegment(value: StatsPeriod.month, label: Text('Month')),
        ButtonSegment(value: StatsPeriod.year, label: Text('Year')),
        ButtonSegment(value: StatsPeriod.total, label: Text('Total')),
      ],
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
      showSelectedIcon: false,
    );
  }
}

class _MonthlyPlaysChart extends StatelessWidget {
  final Map<String, int> data;

  const _MonthlyPlaysChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty || entries.every((e) => e.value == 0)) {
      return const Center(child: Text('No play sessions recorded in this period.'));
    }
    final maxValue = entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue + 1,
        barGroups: List.generate(entries.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].value.toDouble(),
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= entries.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    entries[value.toInt()].key,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _TopWinnersChart extends StatelessWidget {
  final Map<String, int> data;

  const _TopWinnersChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty || entries.every((e) => e.value == 0)) {
      return const Center(child: Text('Add some play results to see winners!'));
    }

    final maxValue = entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue + 1,
        barGroups: List.generate(entries.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].value.toDouble(),
                gradient: const LinearGradient(
                  colors: [Colors.green, Colors.tealAccent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= entries.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    entries[value.toInt()].key,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
