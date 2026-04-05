import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _hrHrvReadings = [];
  List<Map<String, dynamic>> _bpEstimationReadings = [];
  List<Map<String, dynamic>> _bpLogReadings = [];
  bool _isLoading = true;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when returning to this tab (not on first run; initState already loads).
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

      final hrHistory = loggedInUserEmail.isNotEmpty
          ? prefs.getStringList('${loggedInUserEmail}_hrHistory') ?? []
          : prefs.getStringList('hrHistory') ?? [];

      final bpHistory = loggedInUserEmail.isNotEmpty
          ? prefs.getStringList('${loggedInUserEmail}_bpHistory') ?? []
          : prefs.getStringList('bpHistory') ?? [];

      final hrReadings = <Map<String, dynamic>>[];
      final bpEstimationReadings = <Map<String, dynamic>>[];
      final bpLogReadings = <Map<String, dynamic>>[];

      for (final readingJson in hrHistory) {
        try {
          final decoded = jsonDecode(readingJson);
          if (decoded is Map<String, dynamic>) {
            hrReadings.add(decoded);
          }
        } catch (_) {
          // Skip malformed entry
        }
      }

      for (final readingJson in bpHistory) {
        try {
          final decoded = jsonDecode(readingJson);
          if (decoded is Map<String, dynamic>) {
            final type = _parseString(decoded['type']) ?? 'BP';
            if (type == 'BP_LOG') {
              bpLogReadings.add(decoded);
            } else {
              bpEstimationReadings.add(decoded);
            }
          }
        } catch (_) {
          // Skip malformed entry
        }
      }

      int compareByDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
        try {
          final aStr = _parseString(a['date']);
          final bStr = _parseString(b['date']);
          if (aStr == null || bStr == null) return 0;
          final aDate = DateTime.tryParse(aStr);
          final bDate = DateTime.tryParse(bStr);
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        } catch (_) {
          return 0;
        }
      }

      hrReadings.sort(compareByDateDesc);
      bpEstimationReadings.sort(compareByDateDesc);
      bpLogReadings.sort(compareByDateDesc);

      if (!mounted) return;

      setState(() {
        _hrHrvReadings = hrReadings;
        _bpEstimationReadings = bpEstimationReadings;
        _bpLogReadings = bpLogReadings;
        _isLoading = false;
      });
    } on TypeError catch (_) {
      // When e.g. bool is used where double?/int is expected (e.g. after returning from Trends)
      if (!mounted) return;
      setState(() {
        _hrHrvReadings = [];
        _bpEstimationReadings = [];
        _bpLogReadings = [];
        _isLoading = false;
      });
    } catch (_) {
      // On any other error show empty state so we never crash
      if (!mounted) return;
      setState(() {
        _hrHrvReadings = [];
        _bpEstimationReadings = [];
        _bpLogReadings = [];
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = monthNames[date.month - 1];
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute';
  }

  /// Safely convert a dynamic value to double? (handles int, double, String, bool).
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is bool) return null; // Avoid "bool is not a subtype of double?" when data is wrong
    if (value is String) {
      try {
        return double.tryParse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Safely convert a dynamic value to int? (handles int, double, String, bool).
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is bool) return null; // Avoid type cast errors when data is wrong
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Safely convert a dynamic value to String? (handles String, num, bool).
  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  /// Safely convert HRV value to double (legacy name, delegates to _parseDouble).
  double? _parseHRV(dynamic hrvValue) => _parseDouble(hrvValue);

  Widget _safeBuildHrCard(Map<String, dynamic> reading) {
    try {
      return _buildHrHrvCard(reading);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _safeBuildBpCard(Map<String, dynamic> reading, bool isLogRecord) {
    try {
      return _buildBpCard(reading, isLogRecord: isLogRecord);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyData = _hrHrvReadings.isNotEmpty ||
        _bpEstimationReadings.isNotEmpty ||
        _bpLogReadings.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'History',
          style:
              TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasAnyData
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 100, color: Color(0xFFCBD5E0)),
                      SizedBox(height: 16),
                      Text(
                        'No readings yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF718096),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start measuring to see your history',
                        style: TextStyle(color: Color(0xFFA0AEC0)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_hrHrvReadings.isNotEmpty) ...[
                        _buildExpandableSection(
                          sectionKey: 'hr_hrv',
                          icon: Icons.favorite,
                          color: const Color(0xFFFF6B9D),
                          title: 'HR & HRV Records',
                          subtitle:
                              'Saved heart rate and heart rate variability measurements.',
                          children: _hrHrvReadings
                              .map((r) => _safeBuildHrCard(r))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_bpEstimationReadings.isNotEmpty) ...[
                        _buildExpandableSection(
                          sectionKey: 'bp_estimation',
                          icon: Icons.water_drop,
                          color: const Color(0xFF4FACFE),
                          title: 'BP Estimation Records',
                          subtitle:
                              'Blood pressure values estimated from camera measurements.',
                          children: _bpEstimationReadings
                              .map((r) => _safeBuildBpCard(r, false))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_bpLogReadings.isNotEmpty) ...[
                        _buildExpandableSection(
                          sectionKey: 'bp_log',
                          icon: Icons.edit_note,
                          color: const Color(0xFF764BA2),
                          title: 'Recorded BP Records',
                          subtitle:
                              'Blood pressure values you entered manually with notes.',
                          children: _bpLogReadings
                              .map((r) => _safeBuildBpCard(r, true))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildExpandableSection({
    required String sectionKey,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('history_$sectionKey'),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildHrHrvCard(Map<String, dynamic> reading) {
    final dateStr = _parseString(reading['date']);
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final hr = _parseInt(reading['hr']);
    final hrv = _parseHRV(reading['hrv']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B9D), Color(0xFFFFC3A0)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.favorite,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          'HR: ${hr ?? '-'} BPM | HRV: ${hrv != null ? hrv.toStringAsFixed(1) : '-'} ms',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        subtitle: date == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatDate(date),
                  style: const TextStyle(color: Color(0xFF718096)),
                ),
              ),
      ),
    );
  }

  Widget _buildBpCard(Map<String, dynamic> reading,
      {required bool isLogRecord}) {
    final dateStr = _parseString(reading['date']);
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final systolic = _parseInt(reading['systolic']);
    final diastolic = _parseInt(reading['diastolic']);
    final notes = _parseString(reading['notes']);

    final titlePrefix = isLogRecord ? 'BP Recorded' : 'BP Estimation';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLogRecord
                  ? [const Color(0xFF667EEA), const Color(0xFF764BA2)]
                  : [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isLogRecord ? Icons.edit_note : Icons.water_drop,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          '$titlePrefix: ${systolic ?? '-'} / ${diastolic ?? '-'} mmHg',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatDate(date),
                style: const TextStyle(color: Color(0xFF718096)),
              ),
            ],
            if (isLogRecord && notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Notes: $notes',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A5568),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
