import 'dart:async';
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

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late GameRepository _repository;
  bool _isAutoSyncing = false;
  Timer? _syncCheckTimer;
  bool _isSyncCheckRunning = false;
  bool _syncPromptVisible = false;
  int? _lastPromptedRemoteVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
              useRootNavigator: true,
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

    _startPeriodicSyncCheck();
  }
  
  void _showLevelUpDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => LevelUpDialog(
        newLevel: data['newLevel'],
        newBackgroundTier: data['newBackgroundTier'],
        xpForNext: data['xpForNext'],
        leaderboardUnlocked: data['leaderboardUnlocked'] == true,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoSyncOnResume();
    }
  }

  Future<void> _autoSyncOnResume() async {
    if (_isAutoSyncing) return;
    _isAutoSyncing = true;
    try {
      await _repository.loadGames();
    } catch (_) {}
    _isAutoSyncing = false;
  }

  void _startPeriodicSyncCheck() {
    _syncCheckTimer?.cancel();
    _syncCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkRemoteVersion();
    });
  }

  Future<void> _checkRemoteVersion() async {
    if (_isSyncCheckRunning || _syncPromptVisible) return;
    _isSyncCheckRunning = true;
    try {
      final hasCreds = await _repository.hasSyncCredentials();
      if (!hasCreds) {
        _isSyncCheckRunning = false;
        return;
      }

      final remoteVersion = await _repository.fetchRemoteVersion();
      if (remoteVersion == null) {
        _isSyncCheckRunning = false;
        return;
      }

      final localVersion = _repository.dataVersion;
      if (remoteVersion > localVersion &&
          (remoteVersion != _lastPromptedRemoteVersion)) {
        _lastPromptedRemoteVersion = remoteVersion;
        _syncPromptVisible = true;
        if (!mounted) return;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New Sync Available'),
            content: Text('A newer version is available on the server (v$remoteVersion).\n'
                'Do you want to sync now?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sync Now')),
            ],
          ),
        );

        if (confirm == true) {
          await _repository.loadGames();
        }
        _syncPromptVisible = false;
      }
    } catch (_) {
      _syncPromptVisible = false;
    } finally {
      _isSyncCheckRunning = false;
    }
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
      child: SafeArea(
        child: pages[_selectedIndex],
      ),
    );
  }
}
