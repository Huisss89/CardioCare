// // lib/features/home/dashboard_screen.dart
// //
// // Main dashboard. Launches the AI Cardiac Insight Assistant via
// // CardiacAssistantScreen.route(...) when the FAB or header button is tapped.

// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

// import '../../finger_guide_screen.dart';
// import '../measurement/bp/bp_logging_screen.dart';
// import 'cardiac_assistant_screen.dart'; // ← AI assistant + CardiacXaiPayload

// // ─────────────────────────────────────────────────────────────────
// // COLOURS  (matches your app theme)
// // ─────────────────────────────────────────────────────────────────
// const _kPurple1 = Color(0xFF667EEA);
// const _kPurple2 = Color(0xFF764BA2);
// const _kBg      = Color(0xFFF5F7FA);
// const _kDark    = Color(0xFF2D3748);

// // ═════════════════════════════════════════════════════════════════
// // DASHBOARD SCREEN
// // ═════════════════════════════════════════════════════════════════
// class DashboardScreen extends StatefulWidget {
//   final List<CameraDescription> cameras;
//   const DashboardScreen({super.key, required this.cameras});

//   @override
//   _DashboardScreenState createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   String  _userName    = 'User';
//   int?    _lastHR;
//   String? _lastBP;
//   int     _healthScore = 70;

//   // Last 10 readings passed to the AI assistant
//   List<double> _systolicSeries  = [];
//   List<double> _diastolicSeries = [];
//   List<double> _hrSeries        = [];

//   // XAI data from the most recent BP estimation
//   // Saved by your BP measurement screen as: "${email}_bpXai_latest"
//   // Format: { "sbp": {"push_up": [...], "push_down": [...]},
//   //           "dbp": {"push_up": [...], "push_down": [...]} }
//   CardiacXaiPayload? _latestXai;

//   @override
//   void initState() { super.initState(); _loadUserData(); }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _loadUserData();
//   }

//   // ── Load data from SharedPreferences ──────────────────────────────
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final email = prefs.getString('loggedInUserEmail') ?? '';
//     final name  = email.isNotEmpty
//         ? (prefs.getString('${email}_userName') ?? 'User') : 'User';

//     final hrHistory = email.isNotEmpty
//         ? (prefs.getStringList('${email}_hrHistory') ?? []) : <String>[];
//     final bpHistory = email.isNotEmpty
//         ? (prefs.getStringList('${email}_bpHistory') ?? []) : <String>[];

//     int? hr; String? bp; int score = 70;

//     // ── HR series ──────────────────────────────────────────────────
//     final hrSeries = <double>[];
//     for (final raw in hrHistory.reversed) {
//       try {
//         final v = jsonDecode(raw)['hr'] as int?;
//         if (v != null) hrSeries.add(v.toDouble());
//       } catch (_) {}
//     }
//     if (hrSeries.isNotEmpty) {
//       hr = hrSeries.last.toInt();
//       if (hr >= 60 && hr <= 100) score += 10;
//     }

//     // ── BP series ──────────────────────────────────────────────────
//     final allBp = <Map<String, dynamic>>[];
//     for (final raw in bpHistory) {
//       try { allBp.add(jsonDecode(raw)); } catch (_) {}
//     }
//     allBp.sort((a, b) => DateTime.parse(a['date'] as String)
//         .compareTo(DateTime.parse(b['date'] as String)));

//     final sbpSeries = <double>[];
//     final dbpSeries = <double>[];
//     for (final r in allBp) {
//       final s = r['systolic']  as int?;
//       final d = r['diastolic'] as int?;
//       if (s != null) sbpSeries.add(s.toDouble());
//       if (d != null) dbpSeries.add(d.toDouble());
//     }
//     if (sbpSeries.isNotEmpty) {
//       bp = '${sbpSeries.last.toInt()}/${dbpSeries.last.toInt()}';
//       if (sbpSeries.last < 120 && dbpSeries.last < 80) score += 15;
//     }

//     // ── XAI from latest BP measurement ─────────────────────────────
//     // Your BP estimation screen should save this key after each reading.
//     // Example (add to your bp_estimation_screen.dart after getting result):
//     //
//     //   await prefs.setString('${email}_bpXai_latest', jsonEncode({
//     //     'sbp': {
//     //       'push_up':   result['top_sbp_push_up'],   // List<String>
//     //       'push_down': result['top_sbp_push_down'],
//     //     },
//     //     'dbp': {
//     //       'push_up':   result['top_dbp_push_up'],
//     //       'push_down': result['top_dbp_push_down'],
//     //     },
//     //   }));
//     CardiacXaiPayload? xai;
//     final xaiRaw = email.isNotEmpty
//         ? prefs.getString('${email}_bpXai_latest') : null;
//     if (xaiRaw != null) {
//       try {
//         final x   = jsonDecode(xaiRaw) as Map<String, dynamic>;
//         final sbp = x['sbp'] as Map<String, dynamic>?;
//         final dbp = x['dbp'] as Map<String, dynamic>?;
//         if (sbp != null && dbp != null) {
//           xai = CardiacXaiPayload(
//             sbpPushUp:   List<String>.from(sbp['push_up']   ?? []),
//             sbpPushDown: List<String>.from(sbp['push_down'] ?? []),
//             dbpPushUp:   List<String>.from(dbp['push_up']   ?? []),
//             dbpPushDown: List<String>.from(dbp['push_down'] ?? []),
//           );
//         }
//       } catch (_) {}
//     }

//     if (mounted) {
//       setState(() {
//         _userName        = name;
//         _lastHR          = hr;
//         _lastBP          = bp;
//         _healthScore     = score;
//         _latestXai       = xai;
//         _systolicSeries  = sbpSeries.length > 10
//             ? sbpSeries.sublist(sbpSeries.length - 10) : sbpSeries;
//         _diastolicSeries = dbpSeries.length > 10
//             ? dbpSeries.sublist(dbpSeries.length - 10) : dbpSeries;
//         _hrSeries        = hrSeries.length > 10
//             ? hrSeries.sublist(hrSeries.length - 10) : hrSeries;
//       });
//     }
//   }

//   // ── Open AI assistant (slide-up transition) ───────────────────────
//   void _openAssistant() {
//     Navigator.push(
//       context,
//       CardiacAssistantScreen.route(
//         systolicSeries:  _systolicSeries,
//         diastolicSeries: _diastolicSeries,
//         hrSeries:        _hrSeries,
//         xaiPayload:      _latestXai,   // ← passes XAI to assistant
//       ),
//     );
//   }

//   // ── Build ──────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _kBg,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(),
//               const SizedBox(height: 24),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _sectionTitle('Current Status'),
//                     const SizedBox(height: 16),
//                     Row(children: [
//                       Expanded(child: _buildStatusCard(
//                           'Heart Rate',
//                           _lastHR != null ? '$_lastHR' : '--', 'BPM',
//                           Icons.favorite_rounded,
//                           [const Color(0xFFFF6B9D), const Color(0xFFFFC3A0)])),
//                       const SizedBox(width: 12),
//                       Expanded(child: _buildStatusCard(
//                           'Blood Pressure',
//                           _lastBP ?? '--', 'mmHg',
//                           Icons.water_drop_rounded,
//                           [const Color(0xFF4FACFE), const Color(0xFF00F2FE)])),
//                     ]),
//                     const SizedBox(height: 24),
//                     _sectionTitle('Quick Actions'),
//                     const SizedBox(height: 16),
//                     _buildActionCard(
//                         'Full Scan',
//                         'Measure heart rate, HRV and blood pressure in one tap',
//                         Icons.health_and_safety,
//                         [const Color.fromARGB(255, 255, 86, 39),
//                          const Color.fromARGB(255, 184, 212, 73)],
//                         () => Navigator.push(context, MaterialPageRoute(
//                             builder: (_) => FingerGuideScreen(
//                                 cameras: widget.cameras,
//                                 measurementType: 'full')))),
//                     const SizedBox(height: 12),
//                     _buildActionCard(
//                         'Heart Rate Monitor',
//                         'Use camera to measure heart rate',
//                         Icons.camera_alt_rounded,
//                         [const Color(0xFFFF6B9D), const Color(0xFFFFC3A0)],
//                         () => Navigator.push(context, MaterialPageRoute(
//                             builder: (_) => FingerGuideScreen(
//                                 cameras: widget.cameras)))),
//                     const SizedBox(height: 12),
//                     _buildActionCard(
//                         'Blood Pressure Estimation',
//                         'Estimate blood pressure',
//                         Icons.trending_up_rounded,
//                         [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
//                         () => Navigator.push(context, MaterialPageRoute(
//                             builder: (_) => FingerGuideScreen(
//                                 cameras: widget.cameras,
//                                 measurementType: 'bp')))),
//                     const SizedBox(height: 12),
//                     _buildActionCard(
//                         'Log Blood Pressure',
//                         'Manually enter blood pressure readings',
//                         Icons.edit_rounded,
//                         [_kPurple2, _kPurple1],
//                         () => Navigator.push(context, MaterialPageRoute(
//                             builder: (_) => BPLoggingScreen()))),
//                     const SizedBox(height: 90),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),

//       // ── Pulsing purple FAB ─────────────────────────────────────────
//       floatingActionButton: _PulsingFab(onTap: _openAssistant),
//     );
//   }

//   // ── Gradient header ────────────────────────────────────────────────
//   Widget _buildHeader() => Container(
//     padding: const EdgeInsets.all(24),
//     decoration: const BoxDecoration(
//         gradient: LinearGradient(colors: [_kPurple1, _kPurple2])),
//     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//         Expanded(child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Hello, $_userName 👋',
//                 style: const TextStyle(color: Colors.white, fontSize: 24,
//                     fontWeight: FontWeight.bold)),
//             const SizedBox(height: 4),
//             Text('How are you feeling today?',
//                 style: TextStyle(color: Colors.white.withOpacity(0.8),
//                     fontSize: 14)),
//           ],
//         )),
//         // AI Insights pill button in header
//         GestureDetector(
//           onTap: _openAssistant,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.18),
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(
//                   color: Colors.white.withOpacity(0.35), width: 1.5),
//             ),
//             child: const Row(mainAxisSize: MainAxisSize.min, children: [
//               Text('🫀', style: TextStyle(fontSize: 15)),
//               SizedBox(width: 6),
//               Text('AI Insights', style: TextStyle(color: Colors.white,
//                   fontSize: 12, fontWeight: FontWeight.w700)),
//             ]),
//           ),
//         ),
//       ]),
//       const SizedBox(height: 24),
//       // Health Score card
//       Container(
//         padding: const EdgeInsets.all(20),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
//               blurRadius: 20, offset: const Offset(0, 10))],
//         ),
//         child: Row(children: [
//           Stack(alignment: Alignment.center, children: [
//             SizedBox(width: 80, height: 80,
//               child: CircularProgressIndicator(
//                 value: _healthScore / 100, strokeWidth: 8,
//                 backgroundColor: const Color(0xFFE2E8F0),
//                 valueColor: AlwaysStoppedAnimation<Color>(
//                   _healthScore >= 80 ? const Color(0xFF48BB78)
//                       : _healthScore >= 60 ? const Color(0xFFED8936)
//                           : const Color(0xFFF56565),
//                 ),
//               ),
//             ),
//             Text('$_healthScore', style: const TextStyle(fontSize: 24,
//                 fontWeight: FontWeight.bold, color: _kDark)),
//           ]),
//           const SizedBox(width: 20),
//           Expanded(child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text('Health Score',
//                   style: TextStyle(color: Color(0xFF718096), fontSize: 14)),
//               const SizedBox(height: 4),
//               const Text('Based on your health data',
//                   style: TextStyle(color: _kDark, fontSize: 16,
//                       fontWeight: FontWeight.w600)),
//               const SizedBox(height: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 12, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: _healthScore >= 80
//                       ? const Color(0xFF48BB78).withOpacity(0.1)
//                       : const Color(0xFFED8936).withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(_healthScore >= 80 ? 'Good' : 'Fair',
//                     style: TextStyle(
//                       color: _healthScore >= 80
//                           ? const Color(0xFF48BB78)
//                           : const Color(0xFFED8936),
//                       fontWeight: FontWeight.w600, fontSize: 12,
//                     )),
//               ),
//             ],
//           )),
//         ]),
//       ),
//     ]),
//   );

//   Widget _sectionTitle(String text) => Text(text,
//       style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
//           color: _kDark));

//   Widget _buildStatusCard(String title, String value, String unit,
//       IconData icon, List<Color> colors) => Container(
//     padding: const EdgeInsets.all(12),
//     decoration: BoxDecoration(
//       gradient: LinearGradient(colors: colors),
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [BoxShadow(color: colors[0].withOpacity(0.3),
//           blurRadius: 15, offset: const Offset(0, 8))],
//     ),
//     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Icon(icon, color: Colors.white, size: 28),
//       const SizedBox(height: 8),
//       Text(title, style: const TextStyle(color: Colors.white,
//           fontSize: 11, fontWeight: FontWeight.w600)),
//       const SizedBox(height: 4),
//       Row(crossAxisAlignment: CrossAxisAlignment.baseline,
//         textBaseline: TextBaseline.alphabetic,
//         children: [
//           Flexible(child: Text(value,
//               style: const TextStyle(color: Colors.white, fontSize: 20,
//                   fontWeight: FontWeight.bold),
//               maxLines: 1, overflow: TextOverflow.ellipsis)),
//           const SizedBox(width: 4),
//           Padding(padding: const EdgeInsets.only(bottom: 2),
//               child: Text(unit, style: TextStyle(
//                   color: Colors.white.withOpacity(0.8), fontSize: 12))),
//         ]),
//     ]),
//   );

//   Widget _buildActionCard(String title, String subtitle, IconData icon,
//       List<Color> colors, VoidCallback onTap) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: colors),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [BoxShadow(color: colors[0].withOpacity(0.05),
//             blurRadius: 10, offset: const Offset(0, 4))],
//       ),
//       child: Row(children: [
//         Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12)),
//           child: Icon(icon, color: Colors.white, size: 24),
//         ),
//         const SizedBox(width: 16),
//         Expanded(child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(title, style: const TextStyle(color: Colors.white,
//                 fontSize: 16, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 2),
//             Text(subtitle, style: TextStyle(
//                 color: Colors.white.withOpacity(0.8), fontSize: 12)),
//           ],
//         )),
//         Icon(Icons.arrow_forward_rounded,
//             color: Colors.white.withOpacity(0.6), size: 16),
//       ]),
//     ),
//   );
// }

// // ══════════════════════════════════════════════════════════════════
// // PULSING FAB  (local to this file)
// // ══════════════════════════════════════════════════════════════════
// class _PulsingFab extends StatefulWidget {
//   final VoidCallback onTap;
//   const _PulsingFab({required this.onTap});

//   @override
//   State<_PulsingFab> createState() => _PulsingFabState();
// }

// class _PulsingFabState extends State<_PulsingFab>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//   late final Animation<double>   _scale;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(vsync: this,
//         duration: const Duration(milliseconds: 1600))
//       ..repeat(reverse: true);
//     _scale = Tween<double>(begin: 1.0, end: 1.1)
//         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() { _ctrl.dispose(); super.dispose(); }

//   @override
//   Widget build(BuildContext context) => ScaleTransition(
//     scale: _scale,
//     child: GestureDetector(
//       onTap: widget.onTap,
//       child: Container(
//         width: 62, height: 62,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: const LinearGradient(
//             colors: [_kPurple1, _kPurple2],
//             begin: Alignment.topLeft, end: Alignment.bottomRight,
//           ),
//           boxShadow: [BoxShadow(color: _kPurple2.withOpacity(0.5),
//               blurRadius: 20, offset: const Offset(0, 6))],
//         ),
//         child: const Icon(Icons.favorite_rounded,
//             color: Colors.white, size: 28),
//       ),
//     ),
//   );
// }
