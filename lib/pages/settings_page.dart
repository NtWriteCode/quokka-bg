import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quokka/repositories/game_repository.dart';
import 'package:quokka/services/sync_service.dart';

class SettingsPage extends StatefulWidget {
  final GameRepository repository;

  const SettingsPage({super.key, required this.repository});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _syncService = SyncService();
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isTesting = false;
  bool _hasCredentials = false;
  bool _isSyncPromptBusy = false;

  SyncSummary _buildLocalSummary() {
    final stats = widget.repository.userStats;
    final hasData = stats.level > 1 ||
        stats.totalXp > 0 ||
        stats.unlockedAchievementIds.isNotEmpty ||
        widget.repository.ownedGames.isNotEmpty ||
        widget.repository.playRecords.isNotEmpty ||
        widget.repository.players.isNotEmpty;
    return SyncSummary(
      displayName: stats.displayName,
      level: stats.level,
      achievements: stats.unlockedAchievementIds.length,
      totalXp: stats.totalXp.round(),
      games: widget.repository.ownedGames.length,
      plays: widget.repository.playRecords.length,
      players: widget.repository.players.length,
      hasData: hasData,
    );
  }

  String _formatSummary(SyncSummary summary) {
    final nameLine = summary.displayName.isNotEmpty
        ? 'Ranking name: ${summary.displayName}\n'
        : '';
    return '${nameLine}Level ${summary.level} • XP ${summary.totalXp} • Achievements ${summary.achievements}\n'
        'Games ${summary.games} • Plays ${summary.plays} • Players ${summary.players}';
  }

  bool _isSameSummary(SyncSummary a, SyncSummary b) {
    return a.displayName == b.displayName &&
        a.level == b.level &&
        a.achievements == b.achievements &&
        a.totalXp == b.totalXp &&
        a.games == b.games &&
        a.plays == b.plays &&
        a.players == b.players;
  }

  bool _isDowngrade({
    required bool upload,
    required SyncSummary local,
    required SyncSummary remote,
  }) {
    final from = upload ? local : remote;
    final to = upload ? remote : local;

    return from.level < to.level ||
        from.totalXp < to.totalXp ||
        from.achievements < to.achievements ||
        from.games < to.games ||
        from.plays < to.plays ||
        from.players < to.players;
  }

  Future<bool> _confirmSyncReplace({
    required bool upload,
    required SyncSummary local,
    required SyncSummary? remote,
  }) async {
    if (remote == null || !remote.hasData) {
      if (upload) {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Upload to Server?'),
                content: Text(
                  'No remote data was found. Uploading will create a new remote dataset.\n\n'
                  'Local: ${_formatSummary(local)}',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload')),
                ],
              ),
            ) ??
            false;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Remote Data'),
          content: const Text('No remote data was found on the server. Download is not available.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return false;
    }

    if (!_isDowngrade(upload: upload, local: local, remote: remote)) {
      return true;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(upload ? 'Replace Remote Data?' : 'Replace Local Data?'),
            content: Text(
              upload
                  ? 'Remote will be replaced by your local data:\n\n'
                        'Local: ${_formatSummary(local)}\n\n'
                        'Remote: ${_formatSummary(remote)}'
                  : 'Local data will be replaced by remote:\n\n'
                        'Local: ${_formatSummary(local)}\n\n'
                        'Remote: ${_formatSummary(remote)}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(upload ? 'Replace Remote' : 'Replace Local'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _chooseInitialSync({
    required SyncSummary local,
    required SyncSummary? remote,
  }) async {
    if (remote == null || !remote.hasData) {
      return local.hasData ? 'upload' : 'smart';
    }

    if (_isSameSummary(local, remote)) {
      return 'smart';
    }

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Sync Source'),
        content: Text(
          'Which data should be used?\n\n'
          'Local: ${_formatSummary(local)}\n\n'
          'Remote: ${_formatSummary(remote)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'download'), child: const Text('Use Remote')),
          TextButton(onPressed: () => Navigator.pop(context, 'upload'), child: const Text('Use Local')),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    final creds = await _syncService.getCredentials();
    setState(() {
      _urlController.text = creds['url'] ?? '';
      _userController.text = creds['user'] ?? '';
      _passController.text = creds['pass'] ?? '';
      _hasCredentials = creds['url'] != null;
    });
  }

  Future<void> _saveSyncSettings() async {
    final localSummary = _buildLocalSummary();
    
    try {
      if (_isSyncPromptBusy) return;
      _isSyncPromptBusy = true;

      final remoteSummary = await _syncService.fetchRemoteSummary(
        url: _urlController.text.trim(),
        user: _userController.text.trim(),
        pass: _passController.text.trim(),
      );

      final choice = await _chooseInitialSync(local: localSummary, remote: remoteSummary);
      if (choice == null) {
        _isSyncPromptBusy = false;
        return;
      }

      if (choice == 'upload') {
        if (remoteSummary != null && remoteSummary.hasData && _isSameSummary(localSummary, remoteSummary)) {
          _isSyncPromptBusy = false;
          await _performSyncWithProgress(
            syncOperation: () => widget.repository.loadGames(),
            successMessage: 'WebDAV Connected and Synced',
          );
          return;
        }
        final confirmed = await _confirmSyncReplace(
          upload: true,
          local: localSummary,
          remote: remoteSummary,
        );
        if (!confirmed) {
          _isSyncPromptBusy = false;
          return;
        }
      } else if (choice == 'download') {
        if (remoteSummary != null && remoteSummary.hasData && _isSameSummary(localSummary, remoteSummary)) {
          _isSyncPromptBusy = false;
          await _performSyncWithProgress(
            syncOperation: () => widget.repository.loadGames(),
            successMessage: 'WebDAV Connected and Synced',
          );
          return;
        }
        final confirmed = await _confirmSyncReplace(
          upload: false,
          local: localSummary,
          remote: remoteSummary,
        );
        if (!confirmed) {
          _isSyncPromptBusy = false;
          return;
        }
      }

      await _syncService.saveCredentials(
        url: _urlController.text.trim(),
        user: _userController.text.trim(),
        pass: _passController.text.trim(),
      );

      setState(() => _hasCredentials = true);

      if (choice == 'upload') {
        await _performSyncWithProgress(
          syncOperation: () => widget.repository.triggerManualSyncUp(),
          successMessage: 'WebDAV Connected and Data Uploaded',
        );
      } else {
        await _performSyncWithProgress(
          syncOperation: () => widget.repository.loadGames(),
          successMessage: 'WebDAV Connected and Data Synced',
        );
      }
      _isSyncPromptBusy = false;
    } catch (e) {
      _isSyncPromptBusy = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    final error = await _syncService.testConnection(
      url: _urlController.text.trim(),
      user: _userController.text.trim(),
      pass: _passController.text.trim(),
    );
    
    if (!mounted) return;
    setState(() => _isTesting = false);
    
    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection Successful!'), backgroundColor: Colors.green),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Failed'),
            content: SingleChildScrollView(child: Text(error)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _clearCredentials() async {
    await _syncService.clearCredentials();
    _urlController.clear();
    _userController.clear();
    _passController.clear();
    setState(() => _hasCredentials = false);
  }

  /// Perform sync operation with progress dialog after 2 seconds
  Future<void> _performSyncWithProgress({
    required Future<void> Function() syncOperation,
    required String successMessage,
  }) async {
    bool dialogShown = false;
    bool syncCompleted = false;
    
    // Start a timer to show dialog after 2 seconds
    final timer = Timer(const Duration(seconds: 2), () {
      if (!syncCompleted && mounted) {
        dialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Syncing with server...'),
                const SizedBox(height: 8),
                Text(
                  'This may take a while on slow connections',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync continues in background...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Skip'),
              ),
            ],
          ),
        );
      }
    });

    try {
      // Perform the actual sync
      await syncOperation();
      syncCompleted = true;
      timer.cancel();
      
      // Close dialog if it was shown
      if (dialogShown && mounted) {
        Navigator.pop(context);
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      syncCompleted = true;
      timer.cancel();
      
      // Close dialog if it was shown
      if (dialogShown && mounted) {
        Navigator.pop(context);
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader('WebDAV Synchronization'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _hasCredentials ? _buildActiveSyncCard() : _buildSyncLoginForm(),
          ),
          if (_hasCredentials) ...[
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Force Upload to Server'),
              subtitle: const Text('Upload current local data to WebDAV'),
              onTap: () async {
                final localSummary = _buildLocalSummary();
                final remoteSummary = await _syncService.fetchRemoteSummary();
                final confirmed = await _confirmSyncReplace(
                  upload: true,
                  local: localSummary,
                  remote: remoteSummary,
                );
                if (!confirmed) return;

                await _performSyncWithProgress(
                  syncOperation: () => widget.repository.triggerManualSyncUp(),
                  successMessage: 'Data uploaded to server successfully',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Force Download from Server'),
              subtitle: const Text('Download and overwrite local data from WebDAV'),
              onTap: () async {
                final localSummary = _buildLocalSummary();
                final remoteSummary = await _syncService.fetchRemoteSummary();
                final confirmed = await _confirmSyncReplace(
                  upload: false,
                  local: localSummary,
                  remote: remoteSummary,
                );
                if (!confirmed) return;

                await _performSyncWithProgress(
                  syncOperation: () => widget.repository.loadGames(),
                  successMessage: 'Data synced from server successfully',
                );
              },
            ),
          ],
          const Divider(),
          _buildSectionHeader('Display Preferences'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Show Played (Not Owned) Games'),
            subtitle: const Text('Show or hide games you played elsewhere in the collection list'),
            value: widget.repository.showUnownedGames,
            onChanged: (val) async {
              await widget.repository.setShowUnownedGames(val);
              setState(() {});
            },
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          ListTile(
            leading: const Icon(Icons.refresh_outlined, color: Colors.orange),
            title: const Text('Recalculate XP', style: TextStyle(color: Colors.orange)),
            subtitle: const Text('Recalculate your level and XP based on current data'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Recalculate XP?'),
                  content: const Text('This will recalculate your total XP and level based on your current games, plays, and achievements. Your XP history will be cleared, but no data will be lost.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      child: const Text('Recalculate'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // Show loading
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                }

                try {
                  await widget.repository.recalculateXp();
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('XP Recalculated Successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error recalculating XP: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Reset Profile', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Clear all local data and sync this reset to the server'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Everything?'),
                  content: const Text('This will delete all your games, players, plays, and stats. If you have a sync server connected, the data on the server will also be reset. This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reset Everything'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // Show loading
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                }

                try {
                  await widget.repository.resetData();
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile Reset Successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error resetting profile: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),
          const Divider(),
          _buildSectionHeader('Profile'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Display Name'),
            subtitle: Text(widget.repository.userStats.displayName.isEmpty 
                ? 'Not set' 
                : widget.repository.userStats.displayName),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final controller = TextEditingController(
                text: widget.repository.userStats.displayName,
              );
              
              final newName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Edit Display Name'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      hintText: 'Enter your display name',
                      helperText: 'This name will be visible on the leaderboard',
                    ),
                    maxLength: 30,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              
              if (newName != null && newName.isNotEmpty) {
                await widget.repository.updateDisplayName(newName);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Display name updated')),
                  );
                }
              }
            },
          ),
          const Divider(),
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (val) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme switching coming soon!')),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://cloud.example.com/remote.php/webdav/',
            helperText: 'Full absolute URL to your WebDAV endpoint',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userController,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : _testConnection,
              child: _isTesting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test Connection'),
            ),
            ElevatedButton(
              onPressed: _saveSyncSettings,
              child: const Text('Connect & Sync'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSyncCard() {
    return Card(
      elevation: 0,
      color: Colors.green.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done_outlined, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Authenticated with WebDAV', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_urlController.text,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis),
                      Text('User: ${_userController.text}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_alt, size: 18),
                  label: const Text('Test Connection'),
                ),
                TextButton.icon(
                  onPressed: _clearCredentials,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Disconnect'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }
}
