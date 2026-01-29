import 'package:flutter/material.dart';
import 'package:quokka/models/sync_status.dart';
import 'package:quokka/repositories/game_repository.dart';

/// A subtle sync status indicator that shows as a small colored dot.
/// Tapping it reveals the sync history dialog.
class SyncStatusIndicator extends StatelessWidget {
  final GameRepository repository;
  final double size;

  const SyncStatusIndicator({
    super.key,
    required this.repository,
    this.size = 12.0,
  });

  Color _getStatusColor(SyncLogEntry? entry) {
    if (entry == null) return Colors.grey.shade400;
    
    switch (entry.resultType) {
      case SyncResultType.success:
        return Colors.green;
      case SyncResultType.partial:
        return Colors.orange;
      case SyncResultType.failure:
        return Colors.red;
      case SyncResultType.noCredentials:
        return Colors.grey;
      case SyncResultType.skipped:
        return Colors.blue.shade300; // Blue for skipped (already in sync)
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncLogEntry>(
      stream: repository.onSyncStatusChanged,
      builder: (context, snapshot) {
        final entry = snapshot.data ?? repository.lastSyncEntry;
        final color = _getStatusColor(entry);
        
        return GestureDetector(
          onTap: () => showSyncHistoryDialog(context, repository),
          child: Tooltip(
            message: entry?.summary ?? 'No sync yet',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: entry != null && entry.hasIssues
                  ? Icon(
                      Icons.priority_high,
                      size: size * 0.7,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// A more prominent sync status badge for use in settings or profile pages
class SyncStatusBadge extends StatelessWidget {
  final GameRepository repository;

  const SyncStatusBadge({
    super.key,
    required this.repository,
  });

  Color _getStatusColor(SyncLogEntry? entry) {
    if (entry == null) return Colors.grey.shade400;
    
    switch (entry.resultType) {
      case SyncResultType.success:
        return Colors.green;
      case SyncResultType.partial:
        return Colors.orange;
      case SyncResultType.failure:
        return Colors.red;
      case SyncResultType.noCredentials:
        return Colors.grey;
      case SyncResultType.skipped:
        return Colors.blue; // Blue for skipped (already in sync)
    }
  }

  IconData _getStatusIcon(SyncLogEntry? entry) {
    if (entry == null) return Icons.cloud_outlined;
    
    switch (entry.resultType) {
      case SyncResultType.success:
        return Icons.cloud_done;
      case SyncResultType.partial:
        return Icons.cloud_sync;
      case SyncResultType.failure:
        return Icons.cloud_off;
      case SyncResultType.noCredentials:
        return Icons.cloud_outlined;
      case SyncResultType.skipped:
        return Icons.cloud_queue; // Different icon for skipped
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncLogEntry>(
      stream: repository.onSyncStatusChanged,
      builder: (context, snapshot) {
        final entry = snapshot.data ?? repository.lastSyncEntry;
        final color = _getStatusColor(entry);
        
        return GestureDetector(
          onTap: () => showSyncHistoryDialog(context, repository),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(entry),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  entry?.summary ?? 'Not synced yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: color.withOpacity(0.7),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shows the sync history dialog
void showSyncHistoryDialog(BuildContext context, GameRepository repository) {
  showDialog(
    context: context,
    builder: (context) => SyncHistoryDialog(repository: repository),
  );
}

/// The main sync history dialog with expandable entries
class SyncHistoryDialog extends StatefulWidget {
  final GameRepository repository;

  const SyncHistoryDialog({
    super.key,
    required this.repository,
  });

  @override
  State<SyncHistoryDialog> createState() => _SyncHistoryDialogState();
}

class _SyncHistoryDialogState extends State<SyncHistoryDialog> {
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final entries = widget.repository.syncHistory.entries;
    final stats = widget.repository.syncHistory.getStats();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync, size: 24),
          const SizedBox(width: 8),
          const Text('Sync History'),
          const Spacer(),
          if (entries.isNotEmpty)
            _buildStatsBadge(stats),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: entries.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No sync history yet'),
                    const Text(
                      'Sync operations will appear here',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    _buildColorLegend(),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildColorLegend(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isExpanded = _expandedIds.contains(entry.id);
                        
                        return _SyncEntryCard(
                          entry: entry,
                          isExpanded: isExpanded,
                          onToggle: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedIds.remove(entry.id);
                              } else {
                                _expandedIds.add(entry.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        if (entries.isNotEmpty)
          TextButton(
            onPressed: () {
              widget.repository.syncHistory.clear();
              widget.repository.syncHistory.getStats();
              setState(() {});
            },
            child: const Text('Clear History', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildColorLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(Colors.green, 'Success'),
        _buildLegendItem(Colors.blue, 'Skipped'),
        _buildLegendItem(Colors.orange, 'Partial'),
        _buildLegendItem(Colors.red, 'Failed'),
        _buildLegendItem(Colors.grey, 'No Creds'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStatsBadge(Map<String, dynamic> stats) {
    final successRate = stats['successRate'] as int;
    final color = successRate >= 90 ? Colors.green 
        : successRate >= 70 ? Colors.orange 
        : Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$successRate%',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SyncEntryCard extends StatelessWidget {
  final SyncLogEntry entry;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SyncEntryCard({
    required this.entry,
    required this.isExpanded,
    required this.onToggle,
  });

  Color get _statusColor {
    switch (entry.resultType) {
      case SyncResultType.success:
        return Colors.green;
      case SyncResultType.partial:
        return Colors.orange;
      case SyncResultType.failure:
        return Colors.red;
      case SyncResultType.noCredentials:
        return Colors.grey;
      case SyncResultType.skipped:
        return Colors.blue; // Blue for skipped (already in sync)
    }
  }

  IconData get _directionIcon {
    switch (entry.direction) {
      case SyncDirection.upload:
        return Icons.cloud_upload;
      case SyncDirection.download:
        return Icons.cloud_download;
      case SyncDirection.bidirectional:
        return Icons.cloud_sync;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row (always visible)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Direction icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _directionIcon,
                      size: 18,
                      color: _statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.directionLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.resultLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.triggerLabel} • ${_formatTimestamp(entry.timestamp)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // File counts
                  _buildFileCounts(),
                  
                  // Expand icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            
            // Expanded details
            if (isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    
                    // Duration and versions
                    if (entry.durationMs > 0)
                      _buildDetailRow(Icons.timer_outlined, 'Duration: ${entry.durationMs}ms'),
                    if (entry.localVersionBefore != null)
                      _buildDetailRow(Icons.history, 'Local version: ${entry.localVersionBefore} → ${entry.localVersionAfter ?? "?"}'),
                    if (entry.remoteVersion != null)
                      _buildDetailRow(Icons.cloud_outlined, 'Remote version: ${entry.remoteVersion}'),
                    
                    // Successful files
                    if (entry.successfulFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Successful files:',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                      ...entry.successfulFiles.map((f) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(f, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      )),
                    ],
                    
                    // Failed files
                    if (entry.failedFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Failed files:',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                      ...entry.failedFiles.map((f) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.close, size: 12, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(f, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      )),
                    ],
                    
                    // Warnings
                    if (entry.warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Warnings:',
                        style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w600),
                      ),
                      ...entry.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                w,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    
                    // Errors
                    if (entry.errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Errors:',
                        style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600),
                      ),
                      ...entry.errors.map((e) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error, size: 12, color: Colors.red),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCounts() {
    final parts = <Widget>[];
    
    if (entry.filesUploaded > 0) {
      parts.add(_buildCountChip('↑${entry.filesUploaded}', Colors.blue));
    }
    if (entry.filesDownloaded > 0) {
      parts.add(_buildCountChip('↓${entry.filesDownloaded}', Colors.green));
    }
    if (entry.filesFailed > 0) {
      parts.add(_buildCountChip('✗${entry.filesFailed}', Colors.red));
    }
    
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          parts[i],
        ],
      ],
    );
  }

  Widget _buildCountChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
