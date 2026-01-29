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
import 'services/sync_service.dart';
import 'widgets/main_scaffold.dart';
import 'models/sync_status.dart';

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
  bool _isHandlingLifecycle = false;
  SyncTrigger? _lastSyncTrigger;

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

    _repository.onSyncConsent.listen((payload) {
      final local = payload['local'];
      final remote = payload['remote'];
      if (local == null || remote == null) return;
      _showSyncConsentDialog(local, remote);
    });
    
    // Track sync triggers for downgrade dialog
    _repository.onSyncStatusChanged.listen((entry) {
      _lastSyncTrigger = entry.trigger;
    });
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isHandlingLifecycle) return;
    _isHandlingLifecycle = true;
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background - flush pending changes
      _repository.onAppPaused().then((_) {
        _isHandlingLifecycle = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      // App returning from background - smart sync check
      _repository.onAppResumed().then((_) {
        _isHandlingLifecycle = false;
      });
    } else {
      _isHandlingLifecycle = false;
    }
  }

  String _formatSyncSummary(SyncSummary summary) {
    final nameLine = summary.displayName.isNotEmpty
        ? 'Ranking name: ${summary.displayName}\n'
        : '';
    return '${nameLine}Level ${summary.level} • XP ${summary.totalXp} • Achievements ${summary.achievements}\n'
        'Games ${summary.games} • Plays ${summary.plays}';
  }

  String _getTriggerDescription(SyncTrigger? trigger) {
    if (trigger == null) return 'Unknown';
    switch (trigger) {
      case SyncTrigger.appStart:
        return 'App startup sync';
      case SyncTrigger.appResume:
        return 'App resume sync (was in background >5 min)';
      case SyncTrigger.manualUpload:
        return 'Manual upload requested';
      case SyncTrigger.manualDownload:
        return 'Manual download requested';
      case SyncTrigger.autoSync:
        return 'Automatic sync after changes';
      case SyncTrigger.backgroundFlush:
        return 'Auto-save before going to background';
    }
  }

  Future<void> _showSyncConsentDialog(SyncSummary local, SyncSummary remote) async {
    if (!mounted) return;
    final triggerDesc = _getTriggerDescription(_lastSyncTrigger);
    
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Potential Downgrade'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Triggered by: $triggerDesc',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Uploading now would overwrite higher stats on the server:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text('Local:\n${_formatSyncSummary(local)}'),
              const SizedBox(height: 8),
              Text('Remote:\n${_formatSyncSummary(remote)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Upload Anyway'),
          ),
        ],
      ),
    );

    _repository.resolveSyncConsent(confirm == true);
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
