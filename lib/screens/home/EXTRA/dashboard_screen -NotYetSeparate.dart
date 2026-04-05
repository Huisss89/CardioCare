// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:camera/camera.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import 'dart:async';
// import 'package:http/http.dart' as http;
// // import '../../finger_guide_screen.dart';
// // import '../measurement/bp/bp_logging_screen.dart';

// // ─────────────────────────────────────────────────────────────────
// // CONFIG — replace with your Render URL
// // ─────────────────────────────────────────────────────────────────
// const String _kApiBase = 'https://cardiac-insights.onrender.com';

// // ─────────────────────────────────────────────────────────────────
// // COLOURS — matches your existing app theme
// // ─────────────────────────────────────────────────────────────────
// const _kPurple1 = Color(0xFF667EEA);
// const _kPurple2 = Color(0xFF764BA2);
// const _kBg = Color(0xFFF5F7FA);
// const _kDark = Color(0xFF2D3748);

// // AI panel colours
// const _kPanelBg = Color(0xFF1A1A2E);
// const _kCard = Color(0xFF16213E);
// const _kTxtLight = Color(0xFFEAF2FF);
// const _kMuted = Color(0xFF8FA8C8);
// const _kGreen = Color(0xFF4ECDC4);
// const _kWarn = Color(0xFFF4A261);
// const _kAlert = Color(0xFFFF6B6B);

// // ─────────────────────────────────────────────────────────────────
// // MODELS
// // ─────────────────────────────────────────────────────────────────
// class _Insight {
//   final String id, title, icon, category, body;
//   const _Insight(
//       {required this.id,
//       required this.title,
//       required this.icon,
//       required this.category,
//       required this.body});
//   factory _Insight.fromJson(Map<String, dynamic> j) => _Insight(
//         id: j['insight_id'] as String? ?? '',
//         title: j['title'] as String? ?? '',
//         icon: j['icon'] as String? ?? '',
//         category: j['category'] as String? ?? 'attention',
//         body: j['body'] as String? ?? '',
//       );
// }

// class _Trend {
//   final String direction;
//   final double magnitude, latest;
//   const _Trend(
//       {required this.direction, required this.magnitude, required this.latest});
//   factory _Trend.fromJson(Map<String, dynamic> j) => _Trend(
//         direction: j['direction'] as String? ?? 'stable',
//         magnitude: (j['magnitude'] as num?)?.toDouble() ?? 0,
//         latest: (j['latest'] as num?)?.toDouble() ?? 0,
//       );
// }

// class _InsightResponse {
//   final List<_Insight> insights;
//   final Map<String, _Trend> trends;
//   final List<Map<String, dynamic>> flags;
//   final String disclaimer;
//   const _InsightResponse(
//       {required this.insights,
//       required this.trends,
//       required this.flags,
//       required this.disclaimer});
//   factory _InsightResponse.fromJson(Map<String, dynamic> j) => _InsightResponse(
//         insights: (j['insights'] as List? ?? [])
//             .map((e) => _Insight.fromJson(e as Map<String, dynamic>))
//             .toList(),
//         trends: (j['trends'] as Map<String, dynamic>? ?? {}).map(
//             (k, v) => MapEntry(k, _Trend.fromJson(v as Map<String, dynamic>))),
//         flags: (j['flags'] as List? ?? [])
//             .map((e) => e as Map<String, dynamic>)
//             .toList(),
//         disclaimer: j['disclaimer'] as String? ?? '',
//       );
// }

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
//   String _userName = 'User';
//   int? _lastHR;
//   String? _lastBP;
//   int _healthScore = 70;

//   List<double> _systolicSeries = [];
//   List<double> _diastolicSeries = [];
//   List<double> _hrSeries = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _loadUserData();
//   }

//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final email = prefs.getString('loggedInUserEmail') ?? '';
//     final name = email.isNotEmpty
//         ? (prefs.getString('${email}_userName') ?? 'User')
//         : 'User';

//     final hrHistory = email.isNotEmpty
//         ? (prefs.getStringList('${email}_hrHistory') ?? [])
//         : <String>[];
//     final bpHistory = email.isNotEmpty
//         ? (prefs.getStringList('${email}_bpHistory') ?? [])
//         : <String>[];

//     int? hr;
//     String? bp;
//     int score = 70;

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

//     List<Map<String, dynamic>> allBp = [];
//     for (final raw in bpHistory) {
//       try {
//         allBp.add(jsonDecode(raw));
//       } catch (_) {}
//     }
//     allBp.sort((a, b) => DateTime.parse(a['date'] as String)
//         .compareTo(DateTime.parse(b['date'] as String)));

//     final sbpSeries = <double>[];
//     final dbpSeries = <double>[];
//     for (final r in allBp) {
//       final s = r['systolic'] as int?;
//       final d = r['diastolic'] as int?;
//       if (s != null) sbpSeries.add(s.toDouble());
//       if (d != null) dbpSeries.add(d.toDouble());
//     }
//     if (sbpSeries.isNotEmpty) {
//       bp = '${sbpSeries.last.toInt()}/${dbpSeries.last.toInt()}';
//       if (sbpSeries.last < 120 && dbpSeries.last < 80) score += 15;
//     }

//     if (mounted) {
//       setState(() {
//         _userName = name;
//         _lastHR = hr;
//         _lastBP = bp;
//         _healthScore = score;
//         _systolicSeries = sbpSeries.length > 10
//             ? sbpSeries.sublist(sbpSeries.length - 10)
//             : sbpSeries;
//         _diastolicSeries = dbpSeries.length > 10
//             ? dbpSeries.sublist(dbpSeries.length - 10)
//             : dbpSeries;
//         _hrSeries = hrSeries.length > 10
//             ? hrSeries.sublist(hrSeries.length - 10)
//             : hrSeries;
//       });
//     }
//   }

//   void _openAssistant() {
//     Navigator.push(
//       context,
//       PageRouteBuilder(
//         pageBuilder: (_, __, ___) => _CardiacAssistantScreen(
//           systolicSeries: _systolicSeries,
//           diastolicSeries: _diastolicSeries,
//           hrSeries: _hrSeries,
//         ),
//         transitionsBuilder: (_, anim, __, child) => SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(0, 1),
//             end: Offset.zero,
//           ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
//           child: child,
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _kBg,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ── Gradient header ─────────────────────────────────
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(colors: [_kPurple1, _kPurple2]),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Hello, $_userName 👋',
//                                   style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold)),
//                               const SizedBox(height: 4),
//                               Text('How are you feeling today?',
//                                   style: TextStyle(
//                                       color: Colors.white.withOpacity(0.8),
//                                       fontSize: 14)),
//                             ],
//                           ),
//                         ),
//                         // AI Insights pill button in header
//                         GestureDetector(
//                           onTap: _openAssistant,
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 14, vertical: 9),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.18),
//                               borderRadius: BorderRadius.circular(24),
//                               border: Border.all(
//                                   color: Colors.white.withOpacity(0.35),
//                                   width: 1.5),
//                             ),
//                             child: const Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 Text('🫀', style: TextStyle(fontSize: 15)),
//                                 SizedBox(width: 6),
//                                 Text('AI Insights',
//                                     style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 12,
//                                         fontWeight: FontWeight.w700)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//                     // Health Score Card
//                     Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 20,
//                               offset: const Offset(0, 10))
//                         ],
//                       ),
//                       child: Row(children: [
//                         Stack(alignment: Alignment.center, children: [
//                           SizedBox(
//                             width: 80,
//                             height: 80,
//                             child: CircularProgressIndicator(
//                               value: _healthScore / 100,
//                               strokeWidth: 8,
//                               backgroundColor: const Color(0xFFE2E8F0),
//                               valueColor: AlwaysStoppedAnimation<Color>(
//                                 _healthScore >= 80
//                                     ? const Color(0xFF48BB78)
//                                     : _healthScore >= 60
//                                         ? const Color(0xFFED8936)
//                                         : const Color(0xFFF56565),
//                               ),
//                             ),
//                           ),
//                           Text('$_healthScore',
//                               style: const TextStyle(
//                                   fontSize: 24,
//                                   fontWeight: FontWeight.bold,
//                                   color: _kDark)),
//                         ]),
//                         const SizedBox(width: 20),
//                         Expanded(
//                             child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text('Health Score',
//                                 style: TextStyle(
//                                     color: Color(0xFF718096), fontSize: 14)),
//                             const SizedBox(height: 4),
//                             const Text('Based on your health data',
//                                 style: TextStyle(
//                                     color: _kDark,
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.w600)),
//                             const SizedBox(height: 8),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 12, vertical: 4),
//                               decoration: BoxDecoration(
//                                 color: _healthScore >= 80
//                                     ? const Color(0xFF48BB78).withOpacity(0.1)
//                                     : const Color(0xFFED8936).withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 _healthScore >= 80 ? 'Good' : 'Fair',
//                                 style: TextStyle(
//                                   color: _healthScore >= 80
//                                       ? const Color(0xFF48BB78)
//                                       : const Color(0xFFED8936),
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         )),
//                       ]),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 24),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Current Status',
//                         style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: _kDark)),
//                     const SizedBox(height: 16),
//                     Row(children: [
//                       Expanded(
//                           child: _buildStatusCard(
//                               'Heart Rate',
//                               _lastHR != null ? '$_lastHR' : '--',
//                               'BPM',
//                               Icons.favorite_rounded, [
//                         const Color(0xFFFF6B9D),
//                         const Color(0xFFFFC3A0)
//                       ])),
//                       const SizedBox(width: 12),
//                       Expanded(
//                           child: _buildStatusCard(
//                               'Blood Pressure',
//                               _lastBP ?? '--',
//                               'mmHg',
//                               Icons.water_drop_rounded, [
//                         const Color(0xFF4FACFE),
//                         const Color(0xFF00F2FE)
//                       ])),
//                     ]),
//                     const SizedBox(height: 24),
//                     const Text('Quick Actions',
//                         style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: _kDark)),
//                     const SizedBox(height: 16),
//                     _buildActionCard(
//                         'Full Scan',
//                         'Measure heart rate, HRV and blood pressure in one tap',
//                         Icons.health_and_safety,
//                         [
//                           const Color.fromARGB(255, 255, 86, 39),
//                           const Color.fromARGB(255, 184, 212, 73)
//                         ],
//                         () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                                 builder: (_) => FingerGuideScreen(
//                                     cameras: widget.cameras,
//                                     measurementType: 'full')))),
//                     const SizedBox(height: 12),
//                     _buildActionCard(
//                         'Heart Rate Monitor',
//                         'Use camera to measure heart rate',
//                         Icons.camera_alt_rounded,
//                         [const Color(0xFFFF6B9D), const Color(0xFFFFC3A0)],
//                         () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                                 builder: (_) => FingerGuideScreen(
//                                     cameras: widget.cameras)))),
//                     const SizedBox(height: 12),
//                     _buildActionCard(
//                         'Blood Pressure Estimation',
//                         'Estimate blood pressure',
//                         Icons.trending_up_rounded,
//                         [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
//                         () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                                 builder: (_) => FingerGuideScreen(
//                                     cameras: widget.cameras,
//                                     measurementType: 'bp')))),
//                     const SizedBox(height: 12),
//                     _buildActionCard(
//                         'Log Blood Pressure',
//                         'Manually enter blood pressure readings',
//                         Icons.edit_rounded,
//                         [_kPurple2, _kPurple1],
//                         () => Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                                 builder: (_) => BPLoggingScreen()))),
//                     const SizedBox(height: 90),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),

//       // ── Pulsing FAB ──────────────────────────────────────────────
//       floatingActionButton: _PulsingFab(onTap: _openAssistant),
//     );
//   }

//   Widget _buildStatusCard(String title, String value, String unit,
//       IconData icon, List<Color> colors) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: colors),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//               color: colors[0].withOpacity(0.3),
//               blurRadius: 15,
//               offset: const Offset(0, 8))
//         ],
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Icon(icon, color: Colors.white, size: 28),
//         const SizedBox(height: 8),
//         Text(title,
//             style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 11,
//                 fontWeight: FontWeight.w600)),
//         const SizedBox(height: 4),
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.baseline,
//           textBaseline: TextBaseline.alphabetic,
//           children: [
//             Flexible(
//                 child: Text(value,
//                     style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis)),
//             const SizedBox(width: 4),
//             Padding(
//                 padding: const EdgeInsets.only(bottom: 2),
//                 child: Text(unit,
//                     style: TextStyle(
//                         color: Colors.white.withOpacity(0.8), fontSize: 12))),
//           ],
//         ),
//       ]),
//     );
//   }

//   Widget _buildActionCard(String title, String subtitle, IconData icon,
//       List<Color> colors, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(colors: colors),
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//                 color: colors[0].withOpacity(0.05),
//                 blurRadius: 10,
//                 offset: const Offset(0, 4))
//           ],
//         ),
//         child: Row(children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(12)),
//             child: Icon(icon, color: Colors.white, size: 24),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//               child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title,
//                   style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold)),
//               const SizedBox(height: 2),
//               Text(subtitle,
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.8), fontSize: 12)),
//             ],
//           )),
//           Icon(Icons.arrow_forward_rounded,
//               color: Colors.white.withOpacity(0.6), size: 16),
//         ]),
//       ),
//     );
//   }
// }

// // ══════════════════════════════════════════════════════════════════
// // PULSING FAB
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
//   late final Animation<double> _scale;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 1600))
//       ..repeat(reverse: true);
//     _scale = Tween<double>(begin: 1.0, end: 1.1)
//         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ScaleTransition(
//       scale: _scale,
//       child: GestureDetector(
//         onTap: widget.onTap,
//         child: Container(
//           width: 62,
//           height: 62,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             gradient: const LinearGradient(
//               colors: [_kPurple1, _kPurple2],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: _kPurple2.withOpacity(0.5),
//                 blurRadius: 20,
//                 offset: const Offset(0, 6),
//               )
//             ],
//           ),
//           child:
//               const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
//         ),
//       ),
//     );
//   }
// }

// // ══════════════════════════════════════════════════════════════════
// // FULL-SCREEN CARDIAC ASSISTANT  (slides up from bottom)
// // ══════════════════════════════════════════════════════════════════
// class _CardiacAssistantScreen extends StatefulWidget {
//   final List<double> systolicSeries;
//   final List<double> diastolicSeries;
//   final List<double> hrSeries;

//   const _CardiacAssistantScreen({
//     required this.systolicSeries,
//     required this.diastolicSeries,
//     required this.hrSeries,
//   });

//   @override
//   State<_CardiacAssistantScreen> createState() =>
//       _CardiacAssistantScreenState();
// }

// class _CardiacAssistantScreenState extends State<_CardiacAssistantScreen>
//     with SingleTickerProviderStateMixin {
//   late final TabController _tabCtrl;
//   bool _loading = false;
//   bool _fetched = false;
//   _InsightResponse? _result;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _tabCtrl = TabController(length: 3, vsync: this);
//     _fetch();
//   }

//   @override
//   void dispose() {
//     _tabCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _fetch() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final res = await http
//           .post(
//             Uri.parse('$_kApiBase/api/cardiac/insights'),
//             headers: {'Content-Type': 'application/json'},
//             body: jsonEncode({
//               'systolic_series': widget.systolicSeries,
//               'diastolic_series': widget.diastolicSeries,
//               'hr_series': widget.hrSeries,
//               'hrv_series': <double>[],
//             }),
//           )
//           .timeout(const Duration(seconds: 20));

//       if (res.statusCode == 200) {
//         setState(() {
//           _result = _InsightResponse.fromJson(
//               jsonDecode(res.body) as Map<String, dynamic>);
//           _fetched = true;
//           _loading = false;
//         });
//       } else {
//         final err = jsonDecode(res.body) as Map<String, dynamic>;
//         setState(() {
//           _error = err['error'] as String? ?? 'Server error ${res.statusCode}';
//           _loading = false;
//         });
//       }
//     } on TimeoutException {
//       setState(() {
//         _error = 'Request timed out.';
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = 'Could not connect: $e';
//         _loading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: SystemUiOverlayStyle.light,
//       child: Scaffold(
//         backgroundColor: _kPanelBg,
//         body: Column(children: [
//           _buildHeader(context),
//           _buildTabBar(),
//           Expanded(
//             child: _loading
//                 ? _loadingView()
//                 : _error != null
//                     ? _errorView()
//                     : _result == null
//                         ? _loadingView()
//                         : TabBarView(
//                             controller: _tabCtrl,
//                             children: [
//                               _InsightsTab(result: _result!),
//                               _TrendsTab(result: _result!),
//                               _SignalsTab(result: _result!),
//                             ],
//                           ),
//           ),
//         ]),
//       ),
//     );
//   }

//   // ── Header — purple gradient, safe area aware ──────────────────────
//   Widget _buildHeader(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [_kPurple1, _kPurple2],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
//           child: Row(children: [
//             IconButton(
//               icon: const Icon(Icons.arrow_back_ios_rounded,
//                   color: Colors.white, size: 22),
//               onPressed: () => Navigator.pop(context),
//               tooltip: 'Back',
//             ),
//             const SizedBox(width: 2),
//             Expanded(
//                 child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('Cardiac Insight Assistant',
//                     style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold)),
//                 Text('Personal trend analysis · Not medical advice',
//                     style: TextStyle(
//                         color: Colors.white.withOpacity(0.75), fontSize: 11)),
//               ],
//             )),
//             if (_fetched)
//               IconButton(
//                 icon: Icon(Icons.refresh_rounded,
//                     color: Colors.white.withOpacity(0.85), size: 22),
//                 onPressed: _fetch,
//                 tooltip: 'Refresh',
//               ),
//           ]),
//         ),
//       ),
//     );
//   }

//   // ── Tab bar — pill style with rounded corners at bottom ────────────
//   Widget _buildTabBar() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(colors: [_kPurple1, _kPurple2]),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(28),
//           bottomRight: Radius.circular(28),
//         ),
//       ),
//       padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
//       child: TabBar(
//         controller: _tabCtrl,
//         labelColor: Colors.white,
//         unselectedLabelColor: Colors.white54,
//         labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
//         unselectedLabelStyle:
//             const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
//         indicator: BoxDecoration(
//           color: Colors.white.withOpacity(0.22),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         indicatorPadding:
//             const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
//         dividerColor: Colors.transparent,
//         tabs: const [
//           Tab(text: '💡  Insights'),
//           Tab(text: '📈  Trends'),
//           Tab(text: '🔬  Signals'),
//         ],
//       ),
//     );
//   }

//   // ── Loading ────────────────────────────────────────────────────────
//   Widget _loadingView() => Center(
//         child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//           Container(
//             width: 80,
//             height: 80,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: const LinearGradient(colors: [_kPurple1, _kPurple2]),
//               boxShadow: [
//                 BoxShadow(color: _kPurple2.withOpacity(0.4), blurRadius: 24)
//               ],
//             ),
//             child: const Center(
//               child: SizedBox(
//                 width: 36,
//                 height: 36,
//                 child: CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     strokeWidth: 3),
//               ),
//             ),
//           ),
//           const SizedBox(height: 24),
//           const Text('Analysing your cardiac trends…',
//               style: TextStyle(
//                   color: _kTxtLight,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600)),
//           const SizedBox(height: 6),
//           const Text('This only takes a moment',
//               style: TextStyle(color: _kMuted, fontSize: 13)),
//         ]),
//       );

//   // ── Error ─────────────────────────────────────────────────────────
//   Widget _errorView() => Center(
//         child: Padding(
//           padding: const EdgeInsets.all(32),
//           child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//             Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                   shape: BoxShape.circle, color: _kAlert.withOpacity(0.12)),
//               child:
//                   const Icon(Icons.wifi_off_rounded, color: _kAlert, size: 38),
//             ),
//             const SizedBox(height: 20),
//             const Text('Could not load insights',
//                 style: TextStyle(
//                     color: _kTxtLight,
//                     fontSize: 17,
//                     fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Text(_error ?? '',
//                 style: const TextStyle(color: _kMuted, fontSize: 13),
//                 textAlign: TextAlign.center),
//             const SizedBox(height: 28),
//             ElevatedButton.icon(
//               onPressed: _fetch,
//               icon: const Icon(Icons.refresh_rounded),
//               label: const Text('Try Again'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _kPurple1,
//                 foregroundColor: Colors.white,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16)),
//                 elevation: 0,
//               ),
//             ),
//           ]),
//         ),
//       );
// }

// // ══════════════════════════════════════════════════════════════════
// // TAB 1 — INSIGHTS
// // ══════════════════════════════════════════════════════════════════
// class _InsightsTab extends StatelessWidget {
//   final _InsightResponse result;
//   const _InsightsTab({required this.result});

//   Color _catColor(String c) => switch (c) {
//         'alert' => _kAlert,
//         'attention' => _kWarn,
//         'recovery' => _kGreen,
//         'positive' => const Color(0xFF56CFE1),
//         _ => _kMuted,
//       };

//   String _catLabel(String c) => switch (c) {
//         'alert' => '⚠️  Alert',
//         'attention' => '👀  Watch',
//         'recovery' => '💤  Recovery',
//         'positive' => '✅  Good',
//         _ => 'Info',
//       };

//   IconData _iconFor(String key) => switch (key) {
//         'trending_up' => Icons.trending_up_rounded,
//         'trending_down' => Icons.trending_down_rounded,
//         'heart_rising' => Icons.monitor_heart_outlined,
//         'hrv_low' => Icons.favorite_border_rounded,
//         'exertion' => Icons.bolt_rounded,
//         'check_circle' => Icons.check_circle_outline_rounded,
//         'warning' => Icons.warning_amber_rounded,
//         _ => Icons.insights_rounded,
//       };

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
//       children: [
//         if (result.insights.isEmpty)
//           _emptyState()
//         else ...[
//           // Summary banner
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
//             margin: const EdgeInsets.only(bottom: 16),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(colors: [
//                 _kPurple1.withOpacity(0.14),
//                 _kPurple2.withOpacity(0.10),
//               ]),
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: _kPurple1.withOpacity(0.3)),
//             ),
//             child: Row(children: [
//               Container(
//                 width: 44,
//                 height: 44,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   gradient:
//                       const LinearGradient(colors: [_kPurple1, _kPurple2]),
//                 ),
//                 child: const Icon(Icons.favorite_rounded,
//                     color: Colors.white, size: 22),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                   child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     '${result.insights.length} insight'
//                     '${result.insights.length > 1 ? "s" : ""} found',
//                     style: const TextStyle(
//                         color: _kTxtLight,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700),
//                   ),
//                   const Text('Based on your recent cardiac data',
//                       style: TextStyle(color: _kMuted, fontSize: 12)),
//                 ],
//               )),
//             ]),
//           ),
//           ...result.insights.map(_insightCard),
//         ],
//         const SizedBox(height: 8),
//         _disclaimerCard(result.disclaimer),
//       ],
//     );
//   }

//   Widget _insightCard(_Insight ins) {
//     final color = _catColor(ins.category);
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       decoration: BoxDecoration(
//         color: _kCard,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: color.withOpacity(0.3), width: 1.5),
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         // Card header row
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.08),
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//           ),
//           child: Row(children: [
//             Container(
//               width: 42,
//               height: 42,
//               decoration: BoxDecoration(
//                   shape: BoxShape.circle, color: color.withOpacity(0.15)),
//               child: Icon(_iconFor(ins.icon), color: color, size: 20),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//                 child: Text(ins.title,
//                     style: TextStyle(
//                         color: color,
//                         fontSize: 15,
//                         fontWeight: FontWeight.w700))),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(_catLabel(ins.category),
//                   style: TextStyle(
//                       color: color, fontSize: 10, fontWeight: FontWeight.w700)),
//             ),
//           ]),
//         ),
//         // Body text
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//           child: Text(ins.body,
//               style:
//                   const TextStyle(color: _kMuted, fontSize: 13.5, height: 1.7)),
//         ),
//       ]),
//     );
//   }

//   Widget _emptyState() => Padding(
//         padding: const EdgeInsets.symmetric(vertical: 64),
//         child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//           Container(
//             width: 88,
//             height: 88,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: LinearGradient(colors: [
//                 _kGreen.withOpacity(0.2),
//                 _kGreen.withOpacity(0.05)
//               ]),
//             ),
//             child: const Icon(Icons.check_circle_outline_rounded,
//                 color: _kGreen, size: 44),
//           ),
//           const SizedBox(height: 20),
//           const Text('All Looking Good!',
//               style: TextStyle(
//                   color: _kTxtLight,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           const Text(
//             'Your cardiac readings appear stable.\nKeep up your healthy habits!',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: _kMuted, fontSize: 14, height: 1.65),
//           ),
//         ]),
//       );
// }

// // ══════════════════════════════════════════════════════════════════
// // TAB 2 — TRENDS
// // ══════════════════════════════════════════════════════════════════
// class _TrendsTab extends StatelessWidget {
//   final _InsightResponse result;
//   const _TrendsTab({required this.result});

//   Color _dirColor(String d) => d == 'rising'
//       ? _kWarn
//       : d == 'falling'
//           ? _kGreen
//           : _kMuted;
//   IconData _dirIcon(String d) => d == 'rising'
//       ? Icons.arrow_upward_rounded
//       : d == 'falling'
//           ? Icons.arrow_downward_rounded
//           : Icons.remove_rounded;

//   @override
//   Widget build(BuildContext context) {
//     final t = result.trends;
//     final metrics = [
//       _MetricInfo('Systolic BP', 'mmHg', 'systolic', Icons.water_drop_rounded,
//           [_kPurple1, _kPurple2]),
//       _MetricInfo('Diastolic BP', 'mmHg', 'diastolic', Icons.water_outlined,
//           [const Color(0xFF4FACFE), const Color(0xFF00F2FE)]),
//       _MetricInfo('Heart Rate', 'bpm', 'hr', Icons.favorite_rounded,
//           [const Color(0xFFFF6B9D), const Color(0xFFFFC3A0)]),
//       _MetricInfo('HRV', 'ms', 'hrv', Icons.monitor_heart_outlined,
//           [_kGreen, const Color(0xFF1CB5E0)]),
//     ];

//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
//       children: [
//         const Text('Your Recent Trends',
//             style: TextStyle(
//                 color: _kTxtLight, fontSize: 17, fontWeight: FontWeight.bold)),
//         const SizedBox(height: 4),
//         const Text('Based on your last recorded measurements',
//             style: TextStyle(color: _kMuted, fontSize: 12.5)),
//         const SizedBox(height: 18),
//         ...metrics.map((m) => _trendCard(m, t[m.key])),
//         const SizedBox(height: 8),
//         _disclaimerCard(result.disclaimer),
//       ],
//     );
//   }

//   Widget _trendCard(_MetricInfo m, _Trend? trend) {
//     final dir = trend?.direction ?? 'insufficient_data';
//     final col = _dirColor(dir);
//     final isUp = dir == 'rising';
//     final isDown = dir == 'falling';

//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _kCard,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: Colors.white.withOpacity(0.07)),
//       ),
//       child: Row(children: [
//         Container(
//           width: 52,
//           height: 52,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             gradient: LinearGradient(colors: m.colors),
//           ),
//           child: Icon(m.icon, color: Colors.white, size: 24),
//         ),
//         const SizedBox(width: 14),
//         Expanded(
//             child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(m.label,
//                 style: const TextStyle(
//                     color: _kTxtLight,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600)),
//             const SizedBox(height: 4),
//             Row(children: [
//               Icon(_dirIcon(dir), color: col, size: 14),
//               const SizedBox(width: 4),
//               Flexible(
//                   child: Text(
//                 dir == 'insufficient_data'
//                     ? 'Not enough data'
//                     : isUp
//                         ? 'Rising by ${trend!.magnitude.toStringAsFixed(1)} ${m.unit}'
//                         : isDown
//                             ? 'Falling by ${trend!.magnitude.toStringAsFixed(1)} ${m.unit}'
//                             : 'Stable',
//                 style: TextStyle(color: col, fontSize: 12.5),
//               )),
//             ]),
//           ],
//         )),
//         const SizedBox(width: 12),
//         Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
//           Text(
//             trend != null && trend.latest > 0
//                 ? trend.latest.toStringAsFixed(0)
//                 : '—',
//             style: const TextStyle(
//                 color: _kTxtLight, fontSize: 26, fontWeight: FontWeight.bold),
//           ),
//           Text(m.unit, style: const TextStyle(color: _kMuted, fontSize: 11)),
//         ]),
//       ]),
//     );
//   }
// }

// class _MetricInfo {
//   final String label, unit, key;
//   final IconData icon;
//   final List<Color> colors;
//   const _MetricInfo(this.label, this.unit, this.key, this.icon, this.colors);
// }

// // ══════════════════════════════════════════════════════════════════
// // TAB 3 — SIGNALS
// // ══════════════════════════════════════════════════════════════════
// class _SignalsTab extends StatelessWidget {
//   final _InsightResponse result;
//   const _SignalsTab({required this.result});

//   String _metricLabel(String m) => switch (m) {
//         'systolic' => 'Systolic Blood Pressure',
//         'diastolic' => 'Diastolic Blood Pressure',
//         'hr' => 'Heart Rate',
//         'hrv' => 'Heart Rate Variability (HRV)',
//         _ => m,
//       };

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
//       children: [
//         // XAI info banner
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(colors: [
//               _kGreen.withOpacity(0.12),
//               _kGreen.withOpacity(0.03),
//             ]),
//             borderRadius: BorderRadius.circular(18),
//             border: Border.all(color: _kGreen.withOpacity(0.3)),
//           ),
//           child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             Container(
//               width: 44,
//               height: 44,
//               decoration: BoxDecoration(
//                   shape: BoxShape.circle, color: _kGreen.withOpacity(0.15)),
//               child:
//                   const Icon(Icons.insights_rounded, color: _kGreen, size: 22),
//             ),
//             const SizedBox(width: 12),
//             const Expanded(
//                 child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Pulse Signal Analysis',
//                     style: TextStyle(
//                         color: _kTxtLight,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700)),
//                 SizedBox(height: 4),
//                 Text(
//                   'These signals from your PPG sensor most influenced '
//                   'your latest blood pressure estimate.',
//                   style:
//                       TextStyle(color: _kMuted, fontSize: 12.5, height: 1.55),
//                 ),
//               ],
//             )),
//           ]),
//         ),
//         const SizedBox(height: 18),

//         if (result.flags.isEmpty)
//           _noSignalsState()
//         else ...[
//           const Text('Pattern Flags',
//               style: TextStyle(
//                   color: _kWarn, fontSize: 15, fontWeight: FontWeight.w700)),
//           const SizedBox(height: 10),
//           ...result.flags.map(_flagCard),
//         ],

//         const SizedBox(height: 12),
//         _disclaimerCard(result.disclaimer),
//       ],
//     );
//   }

//   Widget _flagCard(Map<String, dynamic> flag) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _kCard,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _kWarn.withOpacity(0.3)),
//       ),
//       child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Container(
//           width: 44,
//           height: 44,
//           decoration: BoxDecoration(
//               shape: BoxShape.circle, color: _kWarn.withOpacity(0.12)),
//           child:
//               const Icon(Icons.warning_amber_rounded, color: _kWarn, size: 22),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//             child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(_metricLabel(flag['metric'] as String? ?? ''),
//                 style: const TextStyle(
//                     color: _kTxtLight,
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600)),
//             const SizedBox(height: 5),
//             Text(flag['message'] as String? ?? '',
//                 style: const TextStyle(
//                     color: _kMuted, fontSize: 13, height: 1.55)),
//           ],
//         )),
//       ]),
//     );
//   }

//   Widget _noSignalsState() => Padding(
//         padding: const EdgeInsets.symmetric(vertical: 48),
//         child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//           Container(
//             width: 80,
//             height: 80,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: LinearGradient(colors: [
//                 _kPurple1.withOpacity(0.2),
//                 _kPurple2.withOpacity(0.08)
//               ]),
//             ),
//             child:
//                 const Icon(Icons.insights_rounded, color: _kPurple1, size: 36),
//           ),
//           const SizedBox(height: 18),
//           const Text('No Signal Flags',
//               style: TextStyle(
//                   color: _kTxtLight,
//                   fontSize: 17,
//                   fontWeight: FontWeight.bold)),
//           const SizedBox(height: 8),
//           const Text(
//             'No abnormal patterns detected.\nTake a measurement to see XAI signals.',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: _kMuted, fontSize: 13.5, height: 1.6),
//           ),
//         ]),
//       );
// }

// // ══════════════════════════════════════════════════════════════════
// // SHARED HELPER
// // ══════════════════════════════════════════════════════════════════
// Widget _disclaimerCard(String text) {
//   return Container(
//     padding: const EdgeInsets.all(14),
//     decoration: BoxDecoration(
//       color: Colors.white.withOpacity(0.04),
//       borderRadius: BorderRadius.circular(14),
//       border: Border.all(color: Colors.white.withOpacity(0.07)),
//     ),
//     child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       const Text('⚕️', style: TextStyle(fontSize: 16)),
//       const SizedBox(width: 10),
//       Expanded(
//           child: Text(
//         text.replaceAll('⚕️ ', ''),
//         style: const TextStyle(color: _kMuted, fontSize: 11.5, height: 1.6),
//       )),
//     ]),
//   );
// }
