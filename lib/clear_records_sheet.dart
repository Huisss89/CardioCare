import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified record entry used in the mixed list
class _RecordEntry {
  final String type; // 'hr' | 'bp_est' | 'bp_log'
  final Map<String, dynamic> data;
  final String originalJson;
  bool selected;

  _RecordEntry({
    required this.type,
    required this.data,
    required this.originalJson,
    this.selected = false,
  });
}

enum _SortOrder { newestFirst, oldestFirst }

/// Shows a bottom sheet where users can select individual health records to delete.
/// Also exposes a "Delete All" option at the top.
///
/// Usage (from profile_screen.dart):
///   showClearRecordsSheet(context, onDeleted: _refreshData);
Future<void> showClearRecordsSheet(
  BuildContext context, {
  VoidCallback? onDeleted,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClearRecordsSheet(onDeleted: onDeleted),
  );
}

class _ClearRecordsSheet extends StatefulWidget {
  final VoidCallback? onDeleted;
  const _ClearRecordsSheet({this.onDeleted});

  @override
  State<_ClearRecordsSheet> createState() => _ClearRecordsSheetState();
}

class _ClearRecordsSheetState extends State<_ClearRecordsSheet> {
  List<_RecordEntry> _records = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  String _loggedInUserEmail = '';

  // Sort state — default newest first
  _SortOrder _sortOrder = _SortOrder.newestFirst;

  // Keys
  String get _hrKey => _loggedInUserEmail.isNotEmpty
      ? '${_loggedInUserEmail}_hrHistory'
      : 'hrHistory';
  String get _bpKey => _loggedInUserEmail.isNotEmpty
      ? '${_loggedInUserEmail}_bpHistory'
      : 'bpHistory';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

    final hrHistory = prefs.getStringList(_hrKey) ?? [];
    final bpHistory = prefs.getStringList(_bpKey) ?? [];

    final entries = <_RecordEntry>[];

    for (final s in hrHistory) {
      try {
        final r = jsonDecode(s) as Map<String, dynamic>;
        entries.add(_RecordEntry(type: 'hr', data: r, originalJson: s));
      } catch (_) {}
    }
    for (final s in bpHistory) {
      try {
        final r = jsonDecode(s) as Map<String, dynamic>;
        final isLog = (r['type'] as String? ?? '') == 'BP_LOG';
        entries.add(_RecordEntry(
          type: isLog ? 'bp_log' : 'bp_est',
          data: r,
          originalJson: s,
        ));
      } catch (_) {}
    }

    _applySortInPlace(entries);

    if (mounted) {
      setState(() {
        _records = entries;
        _isLoading = false;
      });
    }
  }

  // ── Sort ──────────────────────────────────────────────────────────────────

  void _applySortInPlace(List<_RecordEntry> list) {
    list.sort((a, b) {
      try {
        final da = DateTime.parse(a.data['date'] as String);
        final db = DateTime.parse(b.data['date'] as String);
        return _sortOrder == _SortOrder.newestFirst
            ? db.compareTo(da)
            : da.compareTo(db);
      } catch (_) {
        return 0;
      }
    });
  }

  void _toggleSort() {
    setState(() {
      _sortOrder = _sortOrder == _SortOrder.newestFirst
          ? _SortOrder.oldestFirst
          : _SortOrder.newestFirst;
      _applySortInPlace(_records);
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  int get _selectedCount => _records.where((r) => r.selected).length;
  bool get _allSelected =>
      _records.isNotEmpty && _records.every((r) => r.selected);

  Color _typeColor(String type) {
    switch (type) {
      case 'hr':
        return const Color(0xFFFF6B9D);
      case 'bp_est':
        return const Color(0xFF4FACFE);
      case 'bp_log':
        return const Color(0xFF667EEA);
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'hr':
        return Icons.favorite_rounded;
      case 'bp_est':
        return Icons.water_drop_rounded;
      case 'bp_log':
        return Icons.edit_note_rounded;
      default:
        return Icons.circle;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'hr':
        return 'HR & HRV';
      case 'bp_est':
        return 'BP Estimation';
      case 'bp_log':
        return 'Recorded BP';
      default:
        return 'Record';
    }
  }

  String _recordTitle(_RecordEntry entry) {
    final d = entry.data;
    switch (entry.type) {
      case 'hr':
        final hrv = d['hrv'];
        final hrvStr =
            hrv != null ? '${(hrv as num).toStringAsFixed(1)} ms' : '-';
        return 'HR: ${d['hr'] ?? '-'} BPM  •  HRV: $hrvStr';
      case 'bp_est':
      case 'bp_log':
        return 'SYS: ${d['systolic'] ?? '-'}  •  DIA: ${d['diastolic'] ?? '-'} mmHg';
      default:
        return 'Record';
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteSelected({bool all = false}) async {
    final count = all ? _records.length : _selectedCount;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete records?'),
          ],
        ),
        content: Text(
          'You are about to permanently delete $count '
          'record${count == 1 ? '' : 's'}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final toDelete =
          all ? _records.toSet() : _records.where((r) => r.selected).toSet();

      // Separate by storage key
      final deleteHrJsons = toDelete
          .where((r) => r.type == 'hr')
          .map((r) => r.originalJson)
          .toSet();
      final deleteBpJsons = toDelete
          .where((r) => r.type != 'hr')
          .map((r) => r.originalJson)
          .toSet();

      if (deleteHrJsons.isNotEmpty) {
        final existing = prefs.getStringList(_hrKey) ?? [];
        await prefs.setStringList(
            _hrKey, existing.where((s) => !deleteHrJsons.contains(s)).toList());
      }
      if (deleteBpJsons.isNotEmpty) {
        final existing = prefs.getStringList(_bpKey) ?? [];
        await prefs.setStringList(
            _bpKey, existing.where((s) => !deleteBpJsons.contains(s)).toList());
      }

      widget.onDeleted?.call();

      if (mounted) {
        // Reload list (preserves current sort order)
        await _loadRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('$count record${count == 1 ? '' : 's'} deleted'),
              ],
            ),
            backgroundColor: const Color(0xFF48BB78),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Close sheet if no records remain
        if (_records.isEmpty) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: const Color(0xFFF56565),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isNewest = _sortOrder == _SortOrder.newestFirst;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
            color: const Color(0xFFF5F7FA),
            child: Column(
              children: [
                // Title row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF56565).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded,
                          color: Color(0xFFF56565), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clear Records',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748))),
                          Text('Select records to delete',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF718096))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF718096)),
                    ),
                  ],
                ),

                if (!_isLoading && _records.isNotEmpty) ...[
                  const SizedBox(height: 12),

                  // ── Action row: select-all | sort toggle | delete-all ─────
                  Row(
                    children: [
                      // Select all toggle
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            final target = !_allSelected;
                            for (final r in _records) {
                              r.selected = target;
                            }
                          }),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _allSelected
                                      ? const Color(0xFFF56565)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _allSelected
                                        ? const Color(0xFFF56565)
                                        : const Color(0xFFCBD5E0),
                                    width: 1.5,
                                  ),
                                ),
                                child: _allSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _allSelected
                                      ? 'Deselect all'
                                      : 'Select all (${_records.length})',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D3748)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // ── Sort toggle button ──────────────────────────────
                      GestureDetector(
                        onTap: _toggleSort,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4FACFE).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF4FACFE).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isNewest
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 13,
                                color: const Color(0xFF4FACFE),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isNewest ? 'Newest' : 'Oldest',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4FACFE),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Delete All button
                      TextButton.icon(
                        onPressed: _isDeleting
                            ? null
                            : () => _deleteSelected(all: true),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF56565),
                          backgroundColor:
                              const Color(0xFFF56565).withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon:
                            const Icon(Icons.delete_forever_rounded, size: 16),
                        label: const Text('Delete All',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Record list ──────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF56565)),
                  )
                : _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_open_rounded,
                                size: 56, color: Colors.grey[350]),
                            const SizedBox(height: 12),
                            Text('No health records found',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final entry = _records[index];
                          final color = _typeColor(entry.type);
                          final note = entry.data['notes'] as String?;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: entry.selected
                                  ? color.withOpacity(0.07)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: entry.selected
                                    ? color
                                    : const Color(0xFFE2E8F0),
                                width: entry.selected ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(
                                  () => entry.selected = !entry.selected),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: entry.selected
                                            ? color
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: entry.selected
                                              ? color
                                              : const Color(0xFFCBD5E0),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: entry.selected
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 14)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),

                                    // Type badge icon
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(_typeIcon(entry.type),
                                          color: color, size: 16),
                                    ),
                                    const SizedBox(width: 10),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _typeLabel(entry.type),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: color),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _recordTitle(entry),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2D3748)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDate(
                                                entry.data['date'] as String?),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500]),
                                          ),
                                          if (note != null && note.isNotEmpty)
                                            Text(
                                              'Note: $note',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[400],
                                                  fontStyle: FontStyle.italic),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Sticky delete button ─────────────────────────────────────────
          if (_selectedCount > 0)
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isDeleting ? null : () => _deleteSelected(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF56565),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFFF56565).withOpacity(0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_rounded, size: 20),
                  label: Text(
                    _isDeleting
                        ? 'Deleting…'
                        : 'Delete $_selectedCount selected record${_selectedCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
