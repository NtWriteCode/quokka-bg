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
    // Check if user has local data
    final hasLocalData = widget.repository.ownedGames.isNotEmpty || 
                        widget.repository.players.isNotEmpty || 
                        widget.repository.playRecords.isNotEmpty;
    
    // First, ask what to do with local data
    if (hasLocalData) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sync Strategy'),
          content: const Text(
            'You have local data on this device. What would you like to do?\n\n'
            '• Upload: Send your local data to the server (recommended for first sync)\n'
            '• Download: Replace local data with server data\n'
            '• Smart Sync: Automatically sync based on which is newer'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'upload'),
              child: const Text('Upload Local'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'download'),
              child: const Text('Download Server'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'smart'),
              child: const Text('Smart Sync'),
            ),
          ],
        ),
      );

      if (choice == null) return;

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        await _syncService.saveCredentials(
          url: _urlController.text.trim(),
          user: _userController.text.trim(),
          pass: _passController.text.trim(),
        );

        if (choice == 'upload') {
          // Force upload local data to server
          await widget.repository.triggerManualSyncUp();
        } else if (choice == 'download') {
          // Force download from server
          await widget.repository.loadGames();
        } else if (choice == 'smart') {
          // Let the normal sync logic decide
          await widget.repository.loadGames();
        }
        
        setState(() => _hasCredentials = true);
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebDAV Connected and Synced')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error during sync: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // No local data, just save and sync normally
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connect to WebDAV?'),
          content: const Text('This will save the credentials and sync with the server.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Connect')),
          ],
        )
      );

      if (confirm != true) return;

      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      try {
        await _syncService.saveCredentials(
          url: _urlController.text.trim(),
          user: _userController.text.trim(),
          pass: _passController.text.trim(),
        );
        
        await widget.repository.loadGames();
        
        setState(() => _hasCredentials = true);
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebDAV Connected')),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
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
                // Show loading
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                }

                try {
                  await widget.repository.triggerManualSyncUp();
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data uploaded to server successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Force Download from Server'),
              subtitle: const Text('Download and overwrite local data from WebDAV'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Download from Server?'),
                    content: const Text('This will download data from the server and overwrite your local data if the server has a newer version. Any unsaved local changes may be lost.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Download'),
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
                    await widget.repository.loadGames();
                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data synced from server successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
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
