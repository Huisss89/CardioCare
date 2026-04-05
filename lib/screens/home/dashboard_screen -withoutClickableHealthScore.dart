import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../finger_guide_screen.dart';
import '../measurement/bp/bp_logging_screen.dart';
import 'cardiac_chat_screen.dart';
import 'cardiac_assistant_screen.dart'; // brings in HealthScoreEngine
import '../profile/edit_profile_screen.dart'; // ← added for profile redirect

const _kPurple1 = Color(0xFF667EEA);
const _kPurple2 = Color(0xFF764BA2);
const _kBg = Color(0xFFF5F7FA);
const _kDark = Color(0xFF2D3748);

class DashboardScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const DashboardScreen({super.key, required this.cameras});
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = 'User';
  int? _lastHR;
  String? _lastBP;
  int _healthScore = 70;

  List<double> _systolicSeries = [];
  List<double> _diastolicSeries = [];
  List<double> _hrSeries = [];
  List<double> _hrvSeries = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('loggedInUserEmail') ?? '';
    final name = email.isNotEmpty
        ? (prefs.getString('${email}_userName') ?? 'User')
        : 'User';

    final hrHistory = email.isNotEmpty
        ? (prefs.getStringList('${email}_hrHistory') ?? [])
        : <String>[];
    final bpHistory = email.isNotEmpty
        ? (prefs.getStringList('${email}_bpHistory') ?? [])
        : <String>[];
    int? hr;
    String? bp;

    // HR series
    final hrSeries = <double>[];
    for (final raw in hrHistory.reversed) {
      try {
        final v = jsonDecode(raw)['hr'] as int?;
        if (v != null) hrSeries.add(v.toDouble());
      } catch (_) {}
    }
    if (hrSeries.isNotEmpty) {
      hr = hrSeries.last.toInt();
    }

    // HRV series — try every common storage pattern your app might use
    final hrvSeries = <double>[];

    // Pattern 1: dedicated hrvHistory list, entry has 'hrv' field
    final hrvHistory = email.isNotEmpty
        ? (prefs.getStringList('${email}_hrvHistory') ?? [])
        : <String>[];
    for (final raw in hrvHistory.reversed) {
      try {
        final decoded = jsonDecode(raw);
        final v = (decoded['hrv'] ??
            decoded['hrvValue'] ??
            decoded['hrv_ms'] ??
            decoded['value']) as num?;
        if (v != null && v > 0) hrvSeries.add(v.toDouble());
      } catch (_) {}
    }

    // Pattern 2: HRV stored inside hrHistory entries (same list as HR)
    if (hrvSeries.isEmpty) {
      for (final raw in hrHistory.reversed) {
        try {
          final decoded = jsonDecode(raw);
          final v = (decoded['hrv'] ?? decoded['hrvValue'] ?? decoded['hrv_ms'])
              as num?;
          if (v != null && v > 0) hrvSeries.add(v.toDouble());
        } catch (_) {}
      }
    }

    // Pattern 3: HRV stored as a plain double list (not JSON-encoded)
    if (hrvSeries.isEmpty) {
      final plainList = email.isNotEmpty
          ? (prefs.getStringList('${email}_hrv') ?? [])
          : <String>[];
      for (final raw in plainList.reversed) {
        try {
          final v = double.tryParse(raw);
          if (v != null && v > 0) hrvSeries.add(v);
        } catch (_) {}
      }
    }

    // Pattern 4: single latest HRV value stored as string
    if (hrvSeries.isEmpty && email.isNotEmpty) {
      final single = prefs.getString('${email}_lastHrv') ??
          prefs.getString('${email}_hrv_latest');
      if (single != null) {
        final v = double.tryParse(single);
        if (v != null && v > 0) hrvSeries.add(v);
      }
    }

    // BP series
    final allBp = <Map<String, dynamic>>[];
    for (final raw in bpHistory) {
      try {
        allBp.add(jsonDecode(raw));
      } catch (_) {}
    }
    allBp.sort((a, b) => DateTime.parse(a['date'] as String)
        .compareTo(DateTime.parse(b['date'] as String)));

    final sbpSeries = <double>[];
    final dbpSeries = <double>[];
    for (final r in allBp) {
      final s = r['systolic'] as int?;
      final d = r['diastolic'] as int?;
      if (s != null) sbpSeries.add(s.toDouble());
      if (d != null) dbpSeries.add(d.toDouble());
    }
    if (sbpSeries.isNotEmpty) {
      bp = '${sbpSeries.last.toInt()}/${dbpSeries.last.toInt()}';
    }

    const kWindow = 30;
    final sbpTrimmed = sbpSeries.length > kWindow
        ? sbpSeries.sublist(sbpSeries.length - kWindow)
        : sbpSeries;
    final dbpTrimmed = dbpSeries.length > kWindow
        ? dbpSeries.sublist(dbpSeries.length - kWindow)
        : dbpSeries;
    final hrTrimmed = hrSeries.length > kWindow
        ? hrSeries.sublist(hrSeries.length - kWindow)
        : hrSeries;
    final hrvTrimmed = hrvSeries.length > kWindow
        ? hrvSeries.sublist(hrvSeries.length - kWindow)
        : hrvSeries;

    final score = HealthScoreEngine.computeScore(
      sbp: sbpTrimmed,
      dbp: dbpTrimmed,
      hr: hrTrimmed,
      hrv: hrvTrimmed,
    );

    if (mounted) {
      setState(() {
        _userName = name;
        _lastHR = hr;
        _lastBP = bp;
        _healthScore = score;
        _systolicSeries = sbpTrimmed;
        _diastolicSeries = dbpTrimmed;
        _hrSeries = hrTrimmed;
        _hrvSeries = hrvTrimmed;
      });

      // ── Check if Google user has incomplete profile ──────────────────────
      // Reads age, weight, height from prefs. If any are missing or zero,
      // show a one-time prompt to complete the profile.
      if (email.isNotEmpty) {
        final age = prefs.getString('${email}_userAge') ?? '';
        final weight = prefs.getString('${email}_userWeight') ?? '';
        final height = prefs.getString('${email}_userHeight') ?? '';

        final isIncomplete = age.isEmpty ||
            age == '0' ||
            weight.isEmpty ||
            weight == '0' ||
            height.isEmpty ||
            height == '0';

        if (isIncomplete) {
          // Delay slightly so the dashboard renders before the dialog appears
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _showCompleteProfileDialog(email, prefs);
          });
        }
      }
      // ────────────────────────────────────────────────────────────────────
    }
  }

  // ── Incomplete profile alert ─────────────────────────────────────────────
  void _showCompleteProfileDialog(String email, SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kPurple1, _kPurple2]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Complete Your\nProfile',
                style: TextStyle(
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Your profile is missing some health information (age, weight or height).',
              style: TextStyle(
                color: Color(0xFF4A5568),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kPurple1.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kPurple1.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: _kPurple1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This information helps us calculate your health score and provide accurate insights.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kPurple1.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          // "Later" — dismisses without navigating
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF718096),
            ),
            child: const Text('Later',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          // "Update Profile" — closes dialog then opens EditProfileScreen
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    cameras: widget.cameras,
                    userEmail: email,
                    userName: prefs.getString('${email}_userName') ?? 'User',
                    userAge: prefs.getString('${email}_userAge') ?? '',
                    userGender:
                        prefs.getString('${email}_userGender') ?? 'Male',
                    userWeight: prefs.getString('${email}_userWeight') ?? '',
                    userHeight: prefs.getString('${email}_userHeight') ?? '',
                  ),
                ),
              ).then((_) => _loadUserData()); // refresh dashboard on return
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPurple1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Update Profile',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  void _openInsights() {
    Navigator.push(
        context,
        CardiacChatScreen.route(
          systolicSeries: _systolicSeries,
          diastolicSeries: _diastolicSeries,
          hrSeries: _hrSeries,
          hrvSeries: _hrvSeries,
          overallScore: _healthScore,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Current Status'),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _statusCard(
                              'Heart Rate',
                              _lastHR != null ? '$_lastHR' : '--',
                              'BPM',
                              Icons.favorite_rounded, [
                        const Color(0xFFFF6B9D),
                        const Color(0xFFFFC3A0)
                      ])),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statusCard('Blood Pressure', _lastBP ?? '--',
                              'mmHg', Icons.water_drop_rounded, [
                        const Color(0xFF4FACFE),
                        const Color(0xFF00F2FE)
                      ])),
                    ]),
                    const SizedBox(height: 24),
                    _sectionTitle('Quick Actions'),
                    const SizedBox(height: 16),
                    _actionCard(
                        'Full Scan',
                        'Measure heart rate, HRV and blood pressure in one tap',
                        Icons.health_and_safety,
                        [
                          const Color.fromARGB(255, 255, 86, 39),
                          const Color.fromARGB(255, 184, 212, 73)
                        ],
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FingerGuideScreen(
                                    cameras: widget.cameras,
                                    measurementType: 'full')))),
                    const SizedBox(height: 12),
                    _actionCard(
                        'Heart Rate Monitor',
                        'Use camera to measure heart rate',
                        Icons.camera_alt_rounded,
                        [const Color(0xFFFF6B9D), const Color(0xFFFFC3A0)],
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FingerGuideScreen(
                                    cameras: widget.cameras)))),
                    const SizedBox(height: 12),
                    _actionCard(
                        'Blood Pressure Estimation',
                        'Estimate blood pressure',
                        Icons.trending_up_rounded,
                        [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FingerGuideScreen(
                                    cameras: widget.cameras,
                                    measurementType: 'bp')))),
                    const SizedBox(height: 12),
                    _actionCard(
                        'Record Blood Pressure',
                        'Manually enter blood pressure readings',
                        Icons.edit_rounded,
                        [_kPurple2, _kPurple1],
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BPLoggingScreen()))),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _PulsingFab(onTap: _openInsights),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_kPurple1, _kPurple2])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Hi, $_userName 👋',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                ])),
            GestureDetector(
              onTap: _openInsights,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 1.5),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🤍', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 6),
                  Text('Health Insights',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ]),
            child: Row(children: [
              Stack(alignment: Alignment.center, children: [
                SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _healthScore / 100,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_healthScore >= 80
                              ? const Color(0xFF48BB78)
                              : _healthScore >= 60
                                  ? const Color(0xFFED8936)
                                  : const Color(0xFFF56565)),
                    )),
                Text('$_healthScore',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _kDark)),
              ]),
              const SizedBox(width: 20),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Health Score',
                        style:
                            TextStyle(color: Color(0xFF718096), fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Based on your health data',
                        style: TextStyle(
                            color: _kDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _healthScore >= 80
                            ? const Color(0xFF48BB78).withOpacity(0.1)
                            : const Color(0xFFED8936).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_healthScore >= 80 ? 'Good' : 'Fair',
                          style: TextStyle(
                            color: _healthScore >= 80
                                ? const Color(0xFF48BB78)
                                : const Color(0xFFED8936),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          )),
                    ),
                  ])),
            ]),
          ),
        ]),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: _kDark));

  Widget _statusCard(String title, String value, String unit, IconData icon,
          List<Color> colors) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: colors[0].withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                    child: Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(unit,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12))),
              ]),
        ]),
      );

  Widget _actionCard(String title, String subtitle, IconData icon,
          List<Color> colors, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: colors[0].withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ])),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.6), size: 16),
          ]),
        ),
      );
}

class _PulsingFab extends StatefulWidget {
  final VoidCallback onTap;
  const _PulsingFab({required this.onTap});
  @override
  State<_PulsingFab> createState() => _PulsingFabState();
}

class _PulsingFabState extends State<_PulsingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_kPurple1, _kPurple2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: _kPurple2.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 28),
          ),
        ),
      );
}
