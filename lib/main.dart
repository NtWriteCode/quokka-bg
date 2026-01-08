import 'package:flutter/material.dart';
import 'pages/games_list_page.dart';
import 'pages/played_games_page.dart';
import 'pages/stats_page.dart';
import 'pages/settings_page.dart';
import 'pages/profile_page.dart';
import 'pages/library_page.dart';
import 'widgets/achievement_dialog.dart';
import 'repositories/game_repository.dart';
import 'widgets/main_scaffold.dart';

void main() {
  runApp(const BgTrackerApp());
}

class BgTrackerApp extends StatelessWidget {
  const BgTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BG Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _selectedIndex = 0;
  final GameRepository _repository = GameRepository();

  @override
  void initState() {
    super.initState();
    _repository.loadGames();
    _repository.onAchievementsUnlocked.listen((achievements) {
      if (mounted) {
        // Delay slightly to avoid popping up while a page transition is happening,
        // preventing the dialog from accidentally being closed by a Navigator.pop() 
        // intended for the underlying page.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AchievementDialog(achievements: achievements),
            );
          }
        });
      }
    });
  }
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      LibraryPage(repository: _repository),
      StatsPage(repository: _repository),
      PlayedGamesPage(repository: _repository),
      ProfilePage(repository: _repository),
    ];

    return MainScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: pages[_selectedIndex],
    );
  }
}
