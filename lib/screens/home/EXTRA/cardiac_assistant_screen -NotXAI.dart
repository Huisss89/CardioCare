// lib/features/cardiac_assistant/cardiac_assistant_screen.dart
//
// Full-screen Cardiac Insight Assistant.
// Launched from DashboardScreen via Navigator.push (slide-up transition).
// Connects to Flask API on Render.
//
// Usage:
//   Navigator.push(context, CardiacAssistantScreen.route(
//     systolicSeries:  [...],
//     diastolicSeries: [...],
//     hrSeries:        [...],
//   ));

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────
// CONFIG  — replace with your Render service URL
// ─────────────────────────────────────────────────────────────────
const String kCardiacApiBase = 'https://cardiac-insights.onrender.com';

// ─────────────────────────────────────────────────────────────────
// COLOURS  (dark panel palette + app purple accents)
// ─────────────────────────────────────────────────────────────────
const _kPurple1 = Color(0xFF667EEA);
const _kPurple2 = Color(0xFF764BA2);
const _kPanelBg = Color(0xFF1A1A2E);
const _kCard = Color(0xFF16213E);
const _kTxtLight = Color(0xFFEAF2FF);
const _kMuted = Color(0xFF8FA8C8);
const _kGreen = Color(0xFF4ECDC4);
const _kWarn = Color(0xFFF4A261);
const _kAlert = Color(0xFFFF6B6B);

// ─────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────
class CardiacInsight {
  final String id, title, icon, category, body;
  const CardiacInsight({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    required this.body,
  });
  factory CardiacInsight.fromJson(Map<String, dynamic> j) => CardiacInsight(
        id: j['insight_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        icon: j['icon'] as String? ?? '',
        category: j['category'] as String? ?? 'attention',
        body: j['body'] as String? ?? '',
      );
}

class CardiacTrend {
  final String direction;
  final double magnitude, latest;
  const CardiacTrend({
    required this.direction,
    required this.magnitude,
    required this.latest,
  });
  factory CardiacTrend.fromJson(Map<String, dynamic> j) => CardiacTrend(
        direction: j['direction'] as String? ?? 'stable',
        magnitude: (j['magnitude'] as num?)?.toDouble() ?? 0,
        latest: (j['latest'] as num?)?.toDouble() ?? 0,
      );
}

class CardiacInsightResponse {
  final List<CardiacInsight> insights;
  final Map<String, CardiacTrend> trends;
  final List<Map<String, dynamic>> flags;
  final String disclaimer;

  const CardiacInsightResponse({
    required this.insights,
    required this.trends,
    required this.flags,
    required this.disclaimer,
  });

  factory CardiacInsightResponse.fromJson(Map<String, dynamic> j) =>
      CardiacInsightResponse(
        insights: (j['insights'] as List? ?? [])
            .map((e) => CardiacInsight.fromJson(e as Map<String, dynamic>))
            .toList(),
        trends: (j['trends'] as Map<String, dynamic>? ?? {}).map((k, v) =>
            MapEntry(k, CardiacTrend.fromJson(v as Map<String, dynamic>))),
        flags: (j['flags'] as List? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList(),
        disclaimer: j['disclaimer'] as String? ?? '',
      );
}

// ═════════════════════════════════════════════════════════════════
// CARDIAC ASSISTANT SCREEN
// ═════════════════════════════════════════════════════════════════
class CardiacAssistantScreen extends StatefulWidget {
  final List<double> systolicSeries;
  final List<double> diastolicSeries;
  final List<double> hrSeries;

  const CardiacAssistantScreen({
    super.key,
    required this.systolicSeries,
    required this.diastolicSeries,
    required this.hrSeries,
  });

  /// Convenience: creates a slide-up PageRoute ready for Navigator.push
  static Route<void> route({
    required List<double> systolicSeries,
    required List<double> diastolicSeries,
    required List<double> hrSeries,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => CardiacAssistantScreen(
        systolicSeries: systolicSeries,
        diastolicSeries: diastolicSeries,
        hrSeries: hrSeries,
      ),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  State<CardiacAssistantScreen> createState() => _CardiacAssistantScreenState();
}

class _CardiacAssistantScreenState extends State<CardiacAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = false;
  bool _fetched = false;
  CardiacInsightResponse? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── API call ───────────────────────────────────────────────────────
  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse('$kCardiacApiBase/api/cardiac/insights'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systolic_series': widget.systolicSeries,
              'diastolic_series': widget.diastolicSeries,
              'hr_series': widget.hrSeries,
              'hrv_series': <double>[], // add HRV list when available
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        setState(() {
          _result = CardiacInsightResponse.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>);
          _fetched = true;
          _loading = false;
        });
      } else {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _error = err['error'] as String? ?? 'Server error ${res.statusCode}';
          _loading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _error = 'Request timed out. Check your connection.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not connect: $e';
        _loading = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kPanelBg,
        body: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Gradient header — SafeArea aware ──────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPurple1, _kPurple2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cardiac Insight Assistant',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Personal trend analysis · Not medical advice',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (_fetched)
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: Colors.white.withOpacity(0.85), size: 22),
                  onPressed: _fetch,
                  tooltip: 'Refresh insights',
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab bar — pill indicator, rounded bottom ───────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kPurple1, _kPurple2]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.22),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '💡  Insights'),
          Tab(text: '📈  Trends'),
          Tab(text: '🔬  Signals'),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) return _loadingView();
    if (_error != null) return _errorView();
    if (_result == null) return _loadingView();

    return TabBarView(
      controller: _tabCtrl,
      children: [
        _InsightsTab(result: _result!),
        _TrendsTab(result: _result!),
        _SignalsTab(result: _result!),
      ],
    );
  }

  // ── Loading ────────────────────────────────────────────────────────
  Widget _loadingView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_kPurple1, _kPurple2]),
                boxShadow: [
                  BoxShadow(color: _kPurple2.withOpacity(0.4), blurRadius: 24)
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analysing your cardiac trends…',
              style: TextStyle(
                  color: _kTxtLight, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'This only takes a moment',
              style: TextStyle(color: _kMuted, fontSize: 13),
            ),
          ],
        ),
      );

  // ── Error ──────────────────────────────────────────────────────────
  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kAlert.withOpacity(0.12)),
                child: const Icon(Icons.wifi_off_rounded,
                    color: _kAlert, size: 38),
              ),
              const SizedBox(height: 20),
              const Text(
                'Could not load insights',
                style: TextStyle(
                    color: _kTxtLight,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '',
                style: const TextStyle(color: _kMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple1,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// TAB 1 — INSIGHTS
// ══════════════════════════════════════════════════════════════════
class _InsightsTab extends StatelessWidget {
  final CardiacInsightResponse result;
  const _InsightsTab({required this.result});

  Color _catColor(String c) => switch (c) {
        'alert' => _kAlert,
        'attention' => _kWarn,
        'recovery' => _kGreen,
        'positive' => const Color(0xFF56CFE1),
        _ => _kMuted,
      };

  String _catLabel(String c) => switch (c) {
        'alert' => '⚠️  Alert',
        'attention' => '👀  Watch',
        'recovery' => '💤  Recovery',
        'positive' => '✅  Good',
        _ => 'Info',
      };

  IconData _iconFor(String key) => switch (key) {
        'trending_up' => Icons.trending_up_rounded,
        'trending_down' => Icons.trending_down_rounded,
        'heart_rising' => Icons.monitor_heart_outlined,
        'hrv_low' => Icons.favorite_border_rounded,
        'exertion' => Icons.bolt_rounded,
        'check_circle' => Icons.check_circle_outline_rounded,
        'warning' => Icons.warning_amber_rounded,
        _ => Icons.insights_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (result.insights.isEmpty)
          _emptyState()
        else ...[
          // Summary banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _kPurple1.withOpacity(0.14),
                _kPurple2.withOpacity(0.10),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPurple1.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_kPurple1, _kPurple2]),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.insights.length} insight'
                      '${result.insights.length > 1 ? "s" : ""} found',
                      style: const TextStyle(
                          color: _kTxtLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'Based on your recent cardiac data',
                      style: TextStyle(color: _kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          ...result.insights.map(_insightCard),
        ],
        const SizedBox(height: 8),
        cardiacDisclaimerCard(result.disclaimer),
      ],
    );
  }

  Widget _insightCard(CardiacInsight ins) {
    final color = _catColor(ins.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color.withOpacity(0.15)),
                child: Icon(_iconFor(ins.icon), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(ins.title,
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_catLabel(ins.category),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // Body text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Text(ins.body,
                style: const TextStyle(
                    color: _kMuted, fontSize: 13.5, height: 1.7)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  _kGreen.withOpacity(0.2),
                  _kGreen.withOpacity(0.05),
                ]),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: _kGreen, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('All Looking Good!',
                style: TextStyle(
                    color: _kTxtLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'Your cardiac readings appear stable.\nKeep up your healthy habits!',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted, fontSize: 14, height: 1.65),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// TAB 2 — TRENDS
// ══════════════════════════════════════════════════════════════════
class _TrendsTab extends StatelessWidget {
  final CardiacInsightResponse result;
  const _TrendsTab({required this.result});

  Color _dirColor(String d) => d == 'rising'
      ? _kWarn
      : d == 'falling'
          ? _kGreen
          : _kMuted;
  IconData _dirIcon(String d) => d == 'rising'
      ? Icons.arrow_upward_rounded
      : d == 'falling'
          ? Icons.arrow_downward_rounded
          : Icons.remove_rounded;

  @override
  Widget build(BuildContext context) {
    final t = result.trends;
    const metrics = [
      _MetricInfo('Systolic BP', 'mmHg', 'systolic', Icons.water_drop_rounded,
          [_kPurple1, _kPurple2]),
      _MetricInfo('Diastolic BP', 'mmHg', 'diastolic', Icons.water_outlined,
          [Color(0xFF4FACFE), Color(0xFF00F2FE)]),
      _MetricInfo('Heart Rate', 'bpm', 'hr', Icons.favorite_rounded,
          [Color(0xFFFF6B9D), Color(0xFFFFC3A0)]),
      _MetricInfo('HRV', 'ms', 'hrv', Icons.monitor_heart_outlined,
          [_kGreen, Color(0xFF1CB5E0)]),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text('Your Recent Trends',
            style: TextStyle(
                color: _kTxtLight, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Based on your last recorded measurements',
            style: TextStyle(color: _kMuted, fontSize: 12.5)),
        const SizedBox(height: 18),
        ...metrics.map((m) => _trendCard(m, t[m.key])),
        const SizedBox(height: 8),
        cardiacDisclaimerCard(result.disclaimer),
      ],
    );
  }

  Widget _trendCard(_MetricInfo m, CardiacTrend? trend) {
    final dir = trend?.direction ?? 'insufficient_data';
    final col = _dirColor(dir);
    final isUp = dir == 'rising';
    final isDown = dir == 'falling';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: m.colors),
          ),
          child: Icon(m.icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.label,
                  style: const TextStyle(
                      color: _kTxtLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(_dirIcon(dir), color: col, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    dir == 'insufficient_data'
                        ? 'Not enough data'
                        : isUp
                            ? 'Rising by ${trend!.magnitude.toStringAsFixed(1)} ${m.unit}'
                            : isDown
                                ? 'Falling by ${trend!.magnitude.toStringAsFixed(1)} ${m.unit}'
                                : 'Stable',
                    style: TextStyle(color: col, fontSize: 12.5),
                  ),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              trend != null && trend.latest > 0
                  ? trend.latest.toStringAsFixed(0)
                  : '—',
              style: const TextStyle(
                  color: _kTxtLight, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(m.unit, style: const TextStyle(color: _kMuted, fontSize: 11)),
          ],
        ),
      ]),
    );
  }
}

// Small immutable data class used by _TrendsTab
class _MetricInfo {
  final String label, unit, key;
  final IconData icon;
  final List<Color> colors;
  const _MetricInfo(this.label, this.unit, this.key, this.icon, this.colors);
}

// ══════════════════════════════════════════════════════════════════
// TAB 3 — SIGNALS
// ══════════════════════════════════════════════════════════════════
class _SignalsTab extends StatelessWidget {
  final CardiacInsightResponse result;
  const _SignalsTab({required this.result});

  String _metricLabel(String m) => switch (m) {
        'systolic' => 'Systolic Blood Pressure',
        'diastolic' => 'Diastolic Blood Pressure',
        'hr' => 'Heart Rate',
        'hrv' => 'Heart Rate Variability (HRV)',
        _ => m,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // XAI info banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _kGreen.withOpacity(0.12),
              _kGreen.withOpacity(0.03),
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kGreen.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kGreen.withOpacity(0.15)),
                child: const Icon(Icons.insights_rounded,
                    color: _kGreen, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pulse Signal Analysis',
                        style: TextStyle(
                            color: _kTxtLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                      'These signals from your PPG sensor most influenced '
                      'your latest blood pressure estimate.',
                      style: TextStyle(
                          color: _kMuted, fontSize: 12.5, height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (result.flags.isEmpty)
          _noSignalsState()
        else ...[
          const Text('Pattern Flags',
              style: TextStyle(
                  color: _kWarn, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...result.flags.map(_flagCard),
        ],
        const SizedBox(height: 12),
        cardiacDisclaimerCard(result.disclaimer),
      ],
    );
  }

  Widget _flagCard(Map<String, dynamic> flag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kWarn.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: _kWarn.withOpacity(0.12)),
            child: const Icon(Icons.warning_amber_rounded,
                color: _kWarn, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_metricLabel(flag['metric'] as String? ?? ''),
                    style: const TextStyle(
                        color: _kTxtLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(flag['message'] as String? ?? '',
                    style: const TextStyle(
                        color: _kMuted, fontSize: 13, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noSignalsState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  _kPurple1.withOpacity(0.2),
                  _kPurple2.withOpacity(0.08),
                ]),
              ),
              child: const Icon(Icons.insights_rounded,
                  color: _kPurple1, size: 36),
            ),
            const SizedBox(height: 18),
            const Text('No Signal Flags',
                style: TextStyle(
                    color: _kTxtLight,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'No abnormal patterns detected.\nTake a measurement to see XAI signals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kMuted, fontSize: 13.5, height: 1.6),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// SHARED HELPER  — exported so dashboard_screen.dart can also use it
// ══════════════════════════════════════════════════════════════════
Widget cardiacDisclaimerCard(String text) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚕️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text.replaceAll('⚕️ ', ''),
            style: const TextStyle(color: _kMuted, fontSize: 11.5, height: 1.6),
          ),
        ),
      ],
    ),
  );
}
