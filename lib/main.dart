import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/played_games_page.dart';
import 'pages/stats_page.dart';
import 'pages/profile_page.dart';
import 'pages/library_page.dart';
import 'pages/leaderboard_page.dart';
import 'widgets/achievement_dialog.dart';
import 'widgets/level_up_dialog.dart';
import 'repositories/game_repository.dart';
import 'widgets/main_scaffold.dart';

void main() {
  runApp(const QuokkaApp());
}

class QuokkaApp extends StatelessWidget {
  const QuokkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quokka',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider<GameRepository>(
        create: (_) => GameRepository(),
        child: const RootPage(),
      ),
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
  late GameRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = context.read<GameRepository>();
    _repository.loadGames().then((_) {
      // Check daily login bonus after loading
      _repository.checkDailyLoginBonus();
    });
    
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
    
    // Listen for level-up events
    _repository.onLevelUp.listen((levelUpData) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _showLevelUpDialog(levelUpData);
          }
        });
      }
    });
  }
  
  void _showLevelUpDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        newLevel: data['newLevel'],
        newTitle: data['newTitle'],
        newBackgroundTier: data['newBackgroundTier'],
        xpForNext: data['xpForNext'],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      LibraryPage(repository: _repository),
      StatsPage(repository: _repository),
      PlayedGamesPage(repository: _repository),
      const LeaderboardPage(),
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
