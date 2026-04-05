import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF0B0F1A);
const _surface= Color(0xFF131929);
const _card   = Color(0xFF1A2236);
const _card2  = Color(0xFF1F2A40);
const _border = Color(0xFF253047);

const _white  = Color(0xFFFFFFFF);
const _txt    = Color(0xFFDDE6F5);
const _sub    = Color(0xFF7A8BAA);
const _muted  = Color(0xFF4A5568);

// Gradient brand colours (match your app)
const _p1 = Color(0xFF667EEA);
const _p2 = Color(0xFF764BA2);

// Semantic
const _green  = Color(0xFF34D399);
const _greenD = Color(0xFF065F46);
const _amber  = Color(0xFFFBBF24);
const _amberD = Color(0xFF78350F);
const _red    = Color(0xFFF87171);
const _redD   = Color(0xFF7F1D1D);
const _blue   = Color(0xFF60A5FA);
const _blueD  = Color(0xFF1E3A5F);

// ─────────────────────────────────────────────────────────────────
// ENUMS & SIMPLE DATA CLASSES
// ─────────────────────────────────────────────────────────────────
enum _HealthStatus { excellent, good, fair, poor }
enum _MetricStatus { optimal, watch, alert, noData }
enum _TrendDir     { rising, falling, stable, noData }

class _MetricCard {
  final String    label, value, unit, statusLabel, description;
  final IconData  icon;
  final _MetricStatus status;
  final _TrendDir     trend;
  final List<Color>   gradient;
  const _MetricCard({
    required this.label, required this.value, required this.unit,
    required this.statusLabel, required this.description,
    required this.icon, required this.status, required this.trend,
    required this.gradient,
  });
}

class _Insight {
  final String emoji, title, body;
  final _MetricStatus level;
  const _Insight({
    required this.emoji, required this.title,
    required this.body,  required this.level,
  });
}

// ─────────────────────────────────────────────────────────────────
// ON-DEVICE RULE ENGINE
// ─────────────────────────────────────────────────────────────────
// ignore: library_private_types_in_public_api
class HealthScoreEngine {

  // How many recent readings to use for trend & variability analysis.
  // The LATEST value is always used for the metric card regardless of this.
  static const int kTrendWindow = 30;

  // Slice to the most recent kTrendWindow readings for trend calculations
  static List<double> _w(List<double> s) =>
      s.length > kTrendWindow ? s.sublist(s.length - kTrendWindow) : s;

  // ── Utility: linear trend direction ────────────────────────────
  static _TrendDir _trend(List<double> series, double threshold) {
    if (series.length < 3) return _TrendDir.noData;
    final n   = series.length.toDouble();
    final xMean = (n - 1) / 2;
    final yMean = series.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (int i = 0; i < series.length; i++) {
      num += (i - xMean) * (series[i] - yMean);
      den += (i - xMean) * (i - xMean);
    }
    if (den == 0) return _TrendDir.stable;
    final slope = num / den;
    if (slope >  threshold) return _TrendDir.rising;
    if (slope < -threshold) return _TrendDir.falling;
    return _TrendDir.stable;
  }

  // ── Build metric cards ──────────────────────────────────────────
  static List<_MetricCard> buildMetrics(
    List<double> sbp, List<double> dbp,
    List<double> hr,  List<double> hrv,
  ) {
    final cards = <_MetricCard>[];

    // ─── Blood Pressure ────────────────────────────────────────
    if (sbp.isNotEmpty && dbp.isNotEmpty) {
      final s = sbp.last, d = dbp.last;          // always latest value
      final trendDir = _trend(_w(sbp), 0.5);     // trend over last 30
      _MetricStatus st;
      String stLabel, desc;
      if (s < 120 && d < 80) {
        st = _MetricStatus.optimal;
        stLabel = 'Optimal';
        desc = 'Your blood pressure is in the ideal range. '
               'Great for long-term heart health.';
      } else if (s < 130 && d < 80) {
        st = _MetricStatus.watch;
        stLabel = 'Elevated';
        desc = 'Slightly above optimal. Reducing salt, '
               'staying hydrated and regular exercise can help.';
      } else if (s < 140 || d < 90) {
        st = _MetricStatus.watch;
        stLabel = 'Stage 1';
        desc = 'Consistently in Stage 1 range. '
               'Worth discussing lifestyle changes with your doctor.';
      } else {
        st = _MetricStatus.alert;
        stLabel = 'High';
        desc = 'Blood pressure is elevated. '
               'Please consult a healthcare professional.';
      }
      cards.add(_MetricCard(
        label: 'Blood Pressure',
        value: '${s.toInt()}/${d.toInt()}', unit: 'mmHg',
        statusLabel: stLabel, description: desc, status: st, trend: trendDir,
        icon: Icons.water_drop_rounded,
        gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      ));
    } else {
      cards.add(const _MetricCard(
        label: 'Blood Pressure', value: '--/--', unit: 'mmHg',
        statusLabel: 'No data', description: 'No blood pressure readings yet.',
        status: _MetricStatus.noData, trend: _TrendDir.noData,
        icon: Icons.water_drop_rounded,
        gradient: [Color(0xFF667EEA), Color(0xFF764BA2)],
      ));
    }

    // ─── Heart Rate ─────────────────────────────────────────────
    if (hr.isNotEmpty) {
      final h = hr.last;                          // always latest value
      final trendDir = _trend(_w(hr), 0.4);      // trend over last 30
      _MetricStatus st;
      String stLabel, desc;
      if (h >= 60 && h <= 80) {
        st = _MetricStatus.optimal; stLabel = 'Healthy';
        desc = 'A resting heart rate of ${h.toInt()} bpm means '
               'your heart is pumping efficiently.';
      } else if (h > 80 && h <= 100) {
        st = _MetricStatus.watch; stLabel = 'Slightly High';
        desc = '${h.toInt()} bpm is above the ideal resting range. '
               'Stress or caffeine can raise it temporarily.';
      } else if (h < 60 && h >= 50) {
        st = _MetricStatus.optimal; stLabel = 'Athletic';
        desc = 'A lower resting rate (${h.toInt()} bpm) is common '
               'in active people — usually a good sign.';
      } else if (h > 100) {
        st = _MetricStatus.alert; stLabel = 'High';
        desc = 'Resting rate of ${h.toInt()} bpm is above 100. '
               'If this persists, speak to a doctor.';
      } else {
        st = _MetricStatus.watch; stLabel = 'Low';
        desc = '${h.toInt()} bpm is below the typical range. '
               'Monitor and consult a professional if you feel unwell.';
      }
      cards.add(_MetricCard(
        label: 'Heart Rate', value: h.toInt().toString(), unit: 'bpm',
        statusLabel: stLabel, description: desc, status: st, trend: trendDir,
        icon: Icons.favorite_rounded,
        gradient: [const Color(0xFFFF6B9D), const Color(0xFFFF8E53)],
      ));
    } else {
      cards.add(const _MetricCard(
        label: 'Heart Rate', value: '--', unit: 'bpm',
        statusLabel: 'No data', description: 'No heart rate readings yet.',
        status: _MetricStatus.noData, trend: _TrendDir.noData,
        icon: Icons.favorite_rounded,
        gradient: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
      ));
    }

    // ─── HRV ────────────────────────────────────────────────────
    if (hrv.isNotEmpty) {
      final v = hrv.last;                         // always latest value
      final trendDir = _trend(_w(hrv), 0.3);     // trend over last 30
      _MetricStatus st;
      String stLabel, desc;
      if (v >= 50) {
        st = _MetricStatus.optimal; stLabel = 'Excellent';
        desc = 'High HRV (${v.toInt()} ms) means your nervous system '
               'is well-balanced. Your body is recovering well.';
      } else if (v >= 30) {
        st = _MetricStatus.optimal; stLabel = 'Good';
        desc = 'Your HRV of ${v.toInt()} ms is in a healthy range, '
               'showing good adaptability.';
      } else if (v >= 20) {
        st = _MetricStatus.watch; stLabel = 'Moderate';
        desc = 'Your HRV (${v.toInt()} ms) is moderate. '
               'Rest, good sleep and less stress can improve it.';
      } else {
        st = _MetricStatus.alert; stLabel = 'Low';
        desc = 'Low HRV (${v.toInt()} ms) suggests your body is under '
               'stress or fatigue. Prioritise rest today.';
      }
      cards.add(_MetricCard(
        label: 'Heart Rate Variability', value: v.toInt().toString(), unit: 'ms',
        statusLabel: stLabel, description: desc, status: st, trend: trendDir,
        icon: Icons.monitor_heart_outlined,
        gradient: [const Color(0xFF34D399), const Color(0xFF059669)],
      ));
    } else {
      cards.add(const _MetricCard(
        label: 'Heart Rate Variability', value: '--', unit: 'ms',
        statusLabel: 'No data',
        description: 'No HRV data yet. Take a full scan to measure it.',
        status: _MetricStatus.noData, trend: _TrendDir.noData,
        icon: Icons.monitor_heart_outlined,
        gradient: [Color(0xFF34D399), Color(0xFF059669)],
      ));
    }

    return cards;
  }

  // ── Variability (std deviation) of a series ─────────────────────
  static double _variability(List<double> series) {
    if (series.length < 3) return 0;
    final mean = series.reduce((a, b) => a + b) / series.length;
    final variance = series
        .map((x) => math.pow(x - mean, 2).toDouble())
        .reduce((a, b) => a + b) / series.length;
    return math.sqrt(variance);
  }

  // ── Human-friendly window label ──────────────────────────────────
  static String _windowLabel(int count) {
    if (count <= 1) return 'your latest reading';
    if (count <= 3) return 'your last $count readings';
    if (count <= 7) return 'the past $count readings';
    return 'the past ${count} measurements';
  }

  // ── Build insight cards ──────────────────────────────────────────
  static List<_Insight> buildInsights(
    List<double> sbp, List<double> dbp,
    List<double> hr,  List<double> hrv,
  ) {
    final insights = <_Insight>[];
    final double s = sbp.isNotEmpty ? sbp.last : 0;
    final double d = dbp.isNotEmpty ? dbp.last : 0;
    final double h = hr.isNotEmpty  ? hr.last  : 0;
    final double v = hrv.isNotEmpty ? hrv.last  : 0;

    final _TrendDir sbpT = _trend(_w(sbp), 0.5);
    final _TrendDir hrT  = _trend(_w(hr),  0.4);
    final _TrendDir hrvT = _trend(_w(hrv), 0.3);

    // Window labels for time-aware messages (capped at kTrendWindow)
    final sbpWindow = _windowLabel(math.min(sbp.length, kTrendWindow));
    final hrWindow  = _windowLabel(math.min(hr.length,  kTrendWindow));
    final hrvWindow = _windowLabel(math.min(hrv.length, kTrendWindow));

    // Variability over the same window
    final sbpVar = _variability(_w(sbp));
    final hrVar  = _variability(_w(hr));
    final hrvVar = _variability(_w(hrv));

    // ── Data sufficiency check (shown first if insufficient) ──────
    final hasEnoughForTrends = sbp.length >= 3 || hr.length >= 3;
    if (!hasEnoughForTrends && (s > 0 || h > 0 || v > 0)) {
      insights.add(_Insight(
        emoji: '📈', level: _MetricStatus.noData,
        title: 'More Data Needed for Trend Analysis',
        body: 'You have ${math.max(sbp.length, hr.length)} reading'
              '${math.max(sbp.length, hr.length) == 1 ? "" : "s"} so far. '
              'Take measurements regularly over the next few days and '
              'the system will start detecting meaningful trends across '
              'your heart rate, HRV and blood pressure.',
      ));
    }

    // ── Rule 1: All good across all three ─────────────────────────
    if (s > 0 && s < 120 && d < 80 &&
        h > 0 && h >= 60 && h <= 80 &&
        v > 0 && v >= 30) {
      insights.add(_Insight(
        emoji: '💚', level: _MetricStatus.optimal,
        title: 'Your Heart Health Looks Great',
        body: 'Across $sbpWindow, your blood pressure, heart rate, and '
              'HRV are all in healthy ranges at the same time — '
              'a strong indicator of good cardiovascular health.',
      ));
    }

    // ── Rule 2: BP high + HRV low → stress pattern ────────────────
    if (s >= 130 && v > 0 && v < 25) {
      insights.add(_Insight(
        emoji: '🔁', level: _MetricStatus.watch,
        title: 'Signs of Physical Stress',
        body: 'Looking at $sbpWindow, your blood pressure and HRV '
              'together suggest your body is under some stress. '
              'This can come from poor sleep, a busy schedule, or '
              'not enough recovery time. Try a short walk, '
              'deep breathing, or an earlier bedtime.',
      ));
    }

    // ── Rule 3: HR elevated + HRV low → overexertion / fatigue ───
    if (h > 85 && v > 0 && v < 25) {
      insights.add(_Insight(
        emoji: '😴', level: _MetricStatus.watch,
        title: 'Your Body May Need Recovery',
        body: 'Over $hrWindow, a higher heart rate combined with '
              'low HRV often means your body hasn\'t fully recovered. '
              'Consider resting today and avoid intense exercise '
              'until these numbers improve.',
      ));
    }

    // ── Rule 4: BP rising trend ───────────────────────────────────
    if (sbpT == _TrendDir.rising && s >= 125) {
      insights.add(_Insight(
        emoji: '📈', level: _MetricStatus.watch,
        title: 'Blood Pressure Has Been Rising',
        body: 'Across $sbpWindow, your systolic blood pressure has '
              'been gradually increasing. Small lifestyle changes now — '
              'like reducing salt, limiting caffeine and staying active — '
              'can help reverse this trend early.',
      ));
    }

    // ── Rule 5: HRV falling trend ────────────────────────────────
    if (hrvT == _TrendDir.falling && v > 0 && v < 35) {
      insights.add(_Insight(
        emoji: '📉', level: _MetricStatus.watch,
        title: 'HRV Has Been Decreasing',
        body: 'Over $hrvWindow, your heart rate variability has been '
              'dropping consistently. This is often an early signal '
              'of fatigue or stress building up before you notice it. '
              'Prioritise sleep and relaxation.',
      ));
    }

    // ── Rule 6: HR improving trend ───────────────────────────────
    if (hrT == _TrendDir.falling && h > 0 && h >= 60 && h <= 85) {
      insights.add(_Insight(
        emoji: '❤️', level: _MetricStatus.optimal,
        title: 'Heart Rate Has Been Improving',
        body: 'Over $hrWindow, your resting heart rate has been '
              'gradually coming down — a sign your cardiovascular '
              'fitness is improving. Keep up whatever you\'ve been doing!',
      ));
    }

    // ── Rule 7: BP improving ─────────────────────────────────────
    if (sbpT == _TrendDir.falling && s > 0 && s < 130) {
      insights.add(_Insight(
        emoji: '💙', level: _MetricStatus.optimal,
        title: 'Blood Pressure Is Trending Down',
        body: 'Across $sbpWindow, your blood pressure has been '
              'consistently decreasing — a great sign that your '
              'lifestyle choices are having a positive effect on '
              'your heart health.',
      ));
    }

    // ── Rule 8: HRV low alone ────────────────────────────────────
    if (v > 0 && v < 20) {
      insights.add(_Insight(
        emoji: '🌙', level: _MetricStatus.watch,
        title: 'Low HRV — Rest Is Important',
        body: 'Your HRV of ${v.toInt()} ms over $hrvWindow is on '
              'the lower side. HRV reflects how well your nervous '
              'system is coping. Quality sleep, reducing stress, '
              'and light activity are the most effective ways to '
              'bring it back up.',
      ));
    }

    // ── Rule 9: BP alert ─────────────────────────────────────────
    if (s >= 140 || d >= 90) {
      insights.add(_Insight(
        emoji: '⚠️', level: _MetricStatus.alert,
        title: 'Blood Pressure Needs Attention',
        body: 'Your reading of ${s.toInt()}/${d.toInt()} mmHg across '
              '$sbpWindow is in the elevated range. This is worth '
              'discussing with a doctor, especially if you\'ve seen '
              'this on multiple readings.',
      ));
    }

    // ── Rule 10: BP variability high ─────────────────────────────
    if (sbp.length >= 3 && sbpVar > 10) {
      insights.add(_Insight(
        emoji: '📊', level: _MetricStatus.watch,
        title: 'Blood Pressure Fluctuations Detected',
        body: 'Across $sbpWindow, your blood pressure readings vary '
              'significantly between measurements '
              '(±${sbpVar.toStringAsFixed(1)} mmHg). Large fluctuations '
              'can occur due to stress, caffeine, posture or '
              'measurement timing. Try to measure at the same time '
              'each day for more consistent results.',
      ));
    }

    // ── Rule 11: HR variability unusually high ────────────────────
    if (hr.length >= 3 && hrVar > 15) {
      insights.add(_Insight(
        emoji: '💓', level: _MetricStatus.watch,
        title: 'Heart Rate Is Inconsistent',
        body: 'Over $hrWindow, your resting heart rate has varied '
              'by ±${hrVar.toStringAsFixed(1)} bpm between readings. '
              'This can be normal if measurements were taken at '
              'different times of day or activity levels. '
              'Try measuring at rest, at the same time each day.',
      ));
    }

    // ── Rule 12: HRV improving trend ─────────────────────────────
    if (hrvT == _TrendDir.rising && v >= 30) {
      insights.add(_Insight(
        emoji: '🌿', level: _MetricStatus.optimal,
        title: 'HRV Has Been Recovering',
        body: 'Over $hrvWindow, your heart rate variability has been '
              'steadily increasing — a positive sign that your body '
              'is recovering well and adapting to stress more effectively.',
      ));
    }

    // ── Rule 13: Good HRV alone ───────────────────────────────────
    if (v >= 50 && insights.where((i) =>
        i.level == _MetricStatus.optimal).isEmpty) {
      insights.add(_Insight(
        emoji: '🌿', level: _MetricStatus.optimal,
        title: 'Excellent Recovery Capacity',
        body: 'Your HRV of ${v.toInt()} ms over $hrvWindow is high, '
              'which is one of the best indicators of cardiovascular '
              'health and resilience. Your nervous system is '
              'well-balanced and your body is adapting well.',
      ));
    }

    // ── Rule 14: Not enough data at all ───────────────────────────
    if (insights.isEmpty && s == 0 && h == 0 && v == 0) {
      insights.add(const _Insight(
        emoji: '📊', level: _MetricStatus.noData,
        title: 'Take Your First Measurement',
        body: 'No health records found yet. Tap the Full Scan button '
              'on the dashboard to measure your heart rate, HRV and '
              'blood pressure together. The more readings you take, '
              'the more meaningful the analysis becomes.',
      ));
    }

    // ── Rule 15: Stable / no concerning patterns ──────────────────
    if (insights.isEmpty) {
      insights.add(_Insight(
        emoji: '✅', level: _MetricStatus.optimal,
        title: 'All Readings Are Stable',
        body: 'Across $sbpWindow, your heart metrics are all within '
              'a healthy range and not showing any concerning trends. '
              'Keep up your current habits and monitor regularly.',
      ));
    }

    return insights;
  }

  // ── Public entry point for dashboard_screen.dart ─────────────────
  // Returns a 0-100 score using the exact same formula as the assistant.
  static int computeScore({
    required List<double> sbp,
    required List<double> dbp,
    required List<double> hr,
    required List<double> hrv,
  }) {
    final metrics  = buildMetrics(sbp, dbp, hr, hrv);
    final insights = buildInsights(sbp, dbp, hr, hrv);
    final (score, _, __, ___) = overallScore(metrics, insights);
    return score;
  }

  // ── Overall score ────────────────────────────────────────────────
  static (int, _HealthStatus, String, String) overallScore(
    List<_MetricCard> metrics, List<_Insight> insights,
  ) {
    int score = 60;
    for (final m in metrics) {
      if (m.status == _MetricStatus.optimal) score += 12;
      if (m.status == _MetricStatus.watch)   score -= 5;
      if (m.status == _MetricStatus.alert)   score -= 15;
    }
    for (final i in insights) {
      if (i.level == _MetricStatus.optimal) score += 4;
      if (i.level == _MetricStatus.alert)   score -= 8;
    }
    score = score.clamp(0, 100);

    if (score >= 82) return (score, _HealthStatus.excellent,
        'Excellent', 'Your heart health indicators look great.');
    if (score >= 65) return (score, _HealthStatus.good,
        'Good', 'Most metrics look healthy with a couple of things to keep an eye on.');
    if (score >= 45) return (score, _HealthStatus.fair,
        'Needs Attention', 'Some readings are outside the typical healthy range.');
    return (score, _HealthStatus.poor,
        'See a Doctor', 'Several metrics need professional attention soon.');
  }
}

// ═════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════
class CardiacAssistantScreen extends StatefulWidget {
  final List<double> systolicSeries;
  final List<double> diastolicSeries;
  final List<double> hrSeries;
  final List<double> hrvSeries;

  const CardiacAssistantScreen({
    super.key,
    required this.systolicSeries,
    required this.diastolicSeries,
    required this.hrSeries,
    this.hrvSeries = const [],
  });

  static Route<void> route({
    required List<double> systolicSeries,
    required List<double> diastolicSeries,
    required List<double> hrSeries,
    List<double> hrvSeries = const [],
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => CardiacAssistantScreen(
        systolicSeries:  systolicSeries,
        diastolicSeries: diastolicSeries,
        hrSeries:        hrSeries,
        hrvSeries:       hrvSeries,
      ),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  State<CardiacAssistantScreen> createState() =>
      _CardiacAssistantScreenState();
}

class _CardiacAssistantScreenState extends State<CardiacAssistantScreen>
    with TickerProviderStateMixin {

  bool   _loading = true;
  String _loadingMsg = 'Reading your health records…';

  late List<_MetricCard>  _metrics;
  late List<_Insight>     _insights;
  late int                _score;
  late _HealthStatus      _status;
  late String             _statusLabel, _statusSub;

  late final AnimationController _fadeCtrl;

  static const _disclaimer =
    'Smart Health Insights provides personal health observations based on '
    'your recorded measurements. It does not diagnose medical conditions, '
    'recommend medication, or replace professional medical advice. '
    'Always consult a qualified healthcare provider for medical concerns.';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _runAnalysis();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _runAnalysis() async {
    setState(() { _loading = true; });

    // Staged loading messages so the screen feels responsive
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() { _loadingMsg = 'Linking your HR, HRV and BP data…'; });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() { _loadingMsg = 'Building your health picture…'; });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // All analysis runs on-device using the rule engine
    final metrics  = HealthScoreEngine.buildMetrics(
      widget.systolicSeries, widget.diastolicSeries,
      widget.hrSeries,       widget.hrvSeries,
    );
    final insights = HealthScoreEngine.buildInsights(
      widget.systolicSeries, widget.diastolicSeries,
      widget.hrSeries,       widget.hrvSeries,
    );
    final (score, status, label, sub) =
        HealthScoreEngine.overallScore(metrics, insights);

    if (!mounted) return;
    setState(() {
      _metrics     = metrics;
      _insights    = insights;
      _score       = score;
      _status      = status;
      _statusLabel = label;
      _statusSub   = sub;
      _loading     = false;
    });
    _fadeCtrl.forward();
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _Header(onBack: () => Navigator.pop(context),
                onRefresh: _loading ? null : () {
                  _fadeCtrl.reset();
                  _runAnalysis();
                }),
        Expanded(child: _loading ? _LoadingView(message: _loadingMsg)
            : FadeTransition(
                opacity: CurvedAnimation(
                    parent: _fadeCtrl, curve: Curves.easeOut),
                child: _buildContent(),
              )),
      ]),
    ),
  );

  Widget _buildContent() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
    children: [
      _ScoreHero(
          score: _score, status: _status,
          label: _statusLabel, subtitle: _statusSub),
      const SizedBox(height: 16),
      // Analysis window transparency card
      _AnalysisWindowCard(
        sbpCount: widget.systolicSeries.length,
        hrCount:  widget.hrSeries.length,
        hrvCount: widget.hrvSeries.length,
      ),
      const SizedBox(height: 24),
      _SectionLabel(label: 'Your Measurements',
          sub: 'Latest readings at a glance'),
      const SizedBox(height: 12),
      ..._metrics.asMap().entries.map((e) =>
          _AnimatedMetricCard(card: e.value, index: e.key)),
      const SizedBox(height: 24),
      _SectionLabel(label: 'What This Means For You',
          sub: 'Personalised observations based on your records'),
      const SizedBox(height: 12),
      ..._insights.asMap().entries.map((e) =>
          _AnimatedInsightCard(insight: e.value, index: e.key)),
      const SizedBox(height: 20),
      _HowItWorksCard(),
      const SizedBox(height: 16),
      _DisclaimerCard(text: _disclaimer),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  const _Header({required this.onBack, this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
          colors: [_p1, _p2],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: SafeArea(bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 16),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 22),
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Smart Health Insights',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold, letterSpacing: -0.4)),
              Text('Analysing your HR, HRV & blood pressure',
                  style: TextStyle(color: Colors.white.withOpacity(0.72),
                      fontSize: 12)),
            ],
          )),
          if (onRefresh != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: Colors.white.withOpacity(0.85), size: 22),
              onPressed: onRefresh,
              tooltip: 'Refresh analysis',
            ),
        ]),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════
// LOADING VIEW
// ═════════════════════════════════════════════════════════════════
class _LoadingView extends StatefulWidget {
  final String message;
  const _LoadingView({required this.message});
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(_pulse),
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_p1, _p2]),
              boxShadow: [BoxShadow(color: _p2.withOpacity(0.4),
                  blurRadius: 32, spreadRadius: 4)],
            ),
            child: const Center(child: Text('💚',
                style: TextStyle(fontSize: 38))),
          ),
        ),
        const SizedBox(height: 32),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(widget.message,
            key: ValueKey(widget.message),
            style: const TextStyle(color: _txt, fontSize: 16,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        const Text('This takes just a moment',
            style: TextStyle(color: _sub, fontSize: 13)),
        const SizedBox(height: 32),
        SizedBox(width: 200,
          child: LinearProgressIndicator(
            backgroundColor: _card,
            valueColor: const AlwaysStoppedAnimation<Color>(_p1),
            borderRadius: BorderRadius.circular(8),
            minHeight: 4,
          ),
        ),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════
// SCORE HERO CARD
// ═════════════════════════════════════════════════════════════════
class _ScoreHero extends StatelessWidget {
  final int score;
  final _HealthStatus status;
  final String label, subtitle;
  const _ScoreHero({required this.score, required this.status,
      required this.label, required this.subtitle});

  Color get _scoreColor => switch (status) {
    _HealthStatus.excellent => _green,
    _HealthStatus.good      => const Color(0xFF4ADE80),
    _HealthStatus.fair      => _amber,
    _HealthStatus.poor      => _red,
  };

  String get _emoji => switch (status) {
    _HealthStatus.excellent => '💚',
    _HealthStatus.good      => '💛',
    _HealthStatus.fair      => '🟠',
    _HealthStatus.poor      => '❤️‍🩹',
  };

  @override
  Widget build(BuildContext context) {
    final c = _scoreColor;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: c.withOpacity(0.07),
            blurRadius: 32, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Row(children: [
          // Ring
          _ScoreRing(score: score, color: c),
          const SizedBox(width: 20),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: _white, fontSize: 20,
                  fontWeight: FontWeight.bold, height: 1.1)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: _sub,
                  fontSize: 13, height: 1.5)),
            ],
          )),
        ]),
        const SizedBox(height: 20),
        // Scale row
        _ScoreScale(score: score, color: c),
      ]),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 90, height: 90,
    child: Stack(alignment: Alignment.center, children: [
      SizedBox(width: 90, height: 90,
        child: CircularProgressIndicator(
          value: score / 100,
          strokeWidth: 8,
          backgroundColor: Colors.white.withOpacity(0.07),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          strokeCap: StrokeCap.round,
        ),
      ),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$score', style: TextStyle(color: color, fontSize: 28,
            fontWeight: FontWeight.bold, height: 1)),
        Text('/100', style: const TextStyle(color: _sub, fontSize: 11)),
      ]),
    ]),
  );
}

class _ScoreScale extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreScale({required this.score, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(colors: [
          _red.withOpacity(0.6), _amber.withOpacity(0.8),
          _green.withOpacity(0.9), _green]),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: Stack(children: [
          Positioned(
            left: (score / 100) *
                (MediaQuery.of(context).size.width - 32 - 44) - 6,
            top: -2,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: _bg, width: 2.5),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5),
                    blurRadius: 8)],
              ),
            ),
          ),
        ]),
      ),
    ),
    const SizedBox(height: 6),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Poor',      style: TextStyle(color: _muted, fontSize: 10)),
      Text('Fair',      style: TextStyle(color: _muted, fontSize: 10)),
      Text('Good',      style: TextStyle(color: _muted, fontSize: 10)),
      Text('Excellent', style: TextStyle(color: _muted, fontSize: 10)),
    ]),
  ]);
}

// ═════════════════════════════════════════════════════════════════
// SECTION LABEL
// ═════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label, sub;
  const _SectionLabel({required this.label, required this.sub});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: _white, fontSize: 17,
          fontWeight: FontWeight.bold, letterSpacing: -0.3)),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(color: _sub, fontSize: 12.5)),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════
// METRIC CARD  (with trend arrow)
// ═════════════════════════════════════════════════════════════════
class _AnimatedMetricCard extends StatelessWidget {
  final _MetricCard card;
  final int index;
  const _AnimatedMetricCard({required this.card, required this.index});

  Color get _statusColor => switch (card.status) {
    _MetricStatus.optimal => _green,
    _MetricStatus.watch   => _amber,
    _MetricStatus.alert   => _red,
    _MetricStatus.noData  => _sub,
  };

  Color get _statusBg => switch (card.status) {
    _MetricStatus.optimal => _greenD,
    _MetricStatus.watch   => _amberD,
    _MetricStatus.alert   => _redD,
    _MetricStatus.noData  => const Color(0xFF1A2236),
  };

  IconData get _statusIcon => switch (card.status) {
    _MetricStatus.optimal => Icons.check_rounded,
    _MetricStatus.watch   => Icons.remove_rounded,
    _MetricStatus.alert   => Icons.priority_high_rounded,
    _MetricStatus.noData  => Icons.hourglass_empty_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 80),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v,
          child: Transform.translate(offset: Offset(0, 18*(1-v)),
              child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              // Icon
              Container(width: 52, height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: card.gradient)),
                child: Icon(card.icon, color: Colors.white, size: 24)),
              const SizedBox(width: 14),
              // Label + status chips — Expanded so value column never overflows
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.label, style: const TextStyle(color: _sub,
                      fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  // Status chip — full width row, no sibling to fight with
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_statusIcon, color: _statusColor, size: 11),
                      const SizedBox(width: 4),
                      Text(card.statusLabel,
                          style: TextStyle(color: _statusColor,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  // Trend badge on its own line — no overflow possible
                  if (card.trend == _TrendDir.rising ||
                      card.trend == _TrendDir.falling) ...[
                    const SizedBox(height: 5),
                    _TrendBadge(dir: card.trend),
                  ],
                ],
              )),
              const SizedBox(width: 12),
              // Value — fixed width so it never pushes siblings
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(card.value, style: const TextStyle(color: _white,
                    fontSize: 24, fontWeight: FontWeight.bold, height: 1)),
                Text(card.unit, style: const TextStyle(color: _sub,
                    fontSize: 11)),
              ]),
            ]),
          ),
          // Description strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.025),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
            ),
            child: Text(card.description,
                style: const TextStyle(color: _sub, fontSize: 12.5,
                    height: 1.6)),
          ),
        ]),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final _TrendDir dir;
  const _TrendBadge({required this.dir});

  @override
  Widget build(BuildContext context) {
    final isUp   = dir == _TrendDir.rising;
    final isDown = dir == _TrendDir.falling;
    if (!isUp && !isDown) return const SizedBox.shrink();
    final color = isUp ? _amber : _green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isUp ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded, color: color, size: 10),
        const SizedBox(width: 2),
        Text(isUp ? 'Trending up' : 'Trending down',
            style: TextStyle(color: color, fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// INSIGHT CARD
// ═════════════════════════════════════════════════════════════════
class _AnimatedInsightCard extends StatelessWidget {
  final _Insight insight;
  final int index;
  const _AnimatedInsightCard({required this.insight, required this.index});

  Color get _color => switch (insight.level) {
    _MetricStatus.optimal => _green,
    _MetricStatus.watch   => _amber,
    _MetricStatus.alert   => _red,
    _MetricStatus.noData  => _blue,
  };

  Color get _bgColor => switch (insight.level) {
    _MetricStatus.optimal => _greenD,
    _MetricStatus.watch   => _amberD,
    _MetricStatus.alert   => _redD,
    _MetricStatus.noData  => _blueD,
  };

  String get _tag => switch (insight.level) {
    _MetricStatus.optimal => 'Good to know',
    _MetricStatus.watch   => 'Worth watching',
    _MetricStatus.alert   => 'Needs attention',
    _MetricStatus.noData  => 'Get started',
  };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 90),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v,
          child: Transform.translate(offset: Offset(0, 20*(1-v)),
              child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.2), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            decoration: BoxDecoration(
              color: c.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Row(children: [
              Text(insight.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(insight.title,
                  style: TextStyle(color: c, fontSize: 14,
                      fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_tag, style: TextStyle(color: c,
                    fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(insight.body, style: const TextStyle(
                color: _sub, fontSize: 13.5, height: 1.7)),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// ANALYSIS WINDOW CARD
// ═════════════════════════════════════════════════════════════════
class _AnalysisWindowCard extends StatelessWidget {
  final int sbpCount, hrCount, hrvCount;
  const _AnalysisWindowCard({
    required this.sbpCount,
    required this.hrCount,
    required this.hrvCount,
  });

  // Effective window: how many readings are actually used for trend analysis
  int get _effectiveSbp => math.min(sbpCount, HealthScoreEngine.kTrendWindow);
  int get _effectiveHr  => math.min(hrCount,  HealthScoreEngine.kTrendWindow);
  int get _effectiveHrv => math.min(hrvCount, HealthScoreEngine.kTrendWindow);

  String get _progressHint {
    final minCount = [sbpCount, hrCount].where((c) => c > 0)
        .fold(999, math.min);
    if (minCount == 999) return 'Take your first measurement to begin';
    if (minCount < 3)    return '${3 - minCount} more reading${3 - minCount == 1 ? "" : "s"} to unlock trend analysis';
    if (minCount < 5)    return '${5 - minCount} more reading${5 - minCount == 1 ? "" : "s"} for stronger pattern detection';
    return 'Analysing up to ${HealthScoreEngine.kTrendWindow} most recent readings';
  }

  bool get _trendsUnlocked =>
      [sbpCount, hrCount, hrvCount].any((c) => c >= 3);

  bool get _fullAnalysis =>
      [sbpCount, hrCount, hrvCount].any((c) => c >= 5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _p1.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _p1.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics_outlined, color: _p1, size: 16),
          const SizedBox(width: 7),
          const Text('Analysis Based On',
              style: TextStyle(color: _txt, fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        // Data points — shows effective window / total stored
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _DataPill(label: 'BP',  count: _effectiveSbp, total: sbpCount, icon: Icons.water_drop_rounded),
            _DataPill(label: 'HR',  count: _effectiveHr,  total: hrCount,  icon: Icons.favorite_rounded),
            _DataPill(label: 'HRV', count: _effectiveHrv, total: hrvCount, icon: Icons.monitor_heart_outlined),
          ],
        ),
        const SizedBox(height: 10),
        // Capability pills — Wrap so they reflow instead of overflowing
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _CapabilityChip(label: 'Current values',    active: true),
            _CapabilityChip(label: 'Trend analysis',    active: _trendsUnlocked),
            _CapabilityChip(label: 'Pattern detection', active: _fullAnalysis),
          ],
        ),
        if (!_fullAnalysis) ...[
          const SizedBox(height: 8),
          Text(_progressHint,
              style: TextStyle(color: _sub, fontSize: 11, height: 1.4)),
        ],
      ]),
    );
  }
}

class _DataPill extends StatelessWidget {
  final String label;
  final int count;   // readings used in analysis (≤ kTrendWindow)
  final int total;   // total stored readings
  final IconData icon;
  const _DataPill({required this.label, required this.count,
      required this.total, required this.icon});

  @override
  Widget build(BuildContext context) {
    final hasData = total > 0;
    // Show "30/42 BP" when there are more records than the window,
    // otherwise just "7 BP"
    final countLabel = (total > HealthScoreEngine.kTrendWindow)
        ? '$count/${total}'
        : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasData ? _p1.withOpacity(0.12) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasData ? _p1.withOpacity(0.3) : _border,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: hasData ? _p1 : _muted, size: 11),
        const SizedBox(width: 4),
        Text('$countLabel $label',
            style: TextStyle(
              color: hasData ? _txt : _muted,
              fontSize: 11, fontWeight: FontWeight.w600,
            )),
      ]),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  final String label;
  final bool active;
  const _CapabilityChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        active ? Icons.check_circle_rounded
               : Icons.radio_button_unchecked_rounded,
        color: active ? _green : _muted,
        size: 12,
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
            color: active ? _txt : _muted,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════
// HOW IT WORKS CARD
// ═════════════════════════════════════════════════════════════════
class _HowItWorksCard extends StatefulWidget {
  const _HowItWorksCard();
  @override
  State<_HowItWorksCard> createState() => _HowItWorksCardState();
}

class _HowItWorksCardState extends State<_HowItWorksCard>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double>   _expand, _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 260));
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotate = Tween<double>(begin: 0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _card2,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Column(children: [
      InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _p1.withOpacity(0.12)),
              child: const Icon(Icons.help_outline_rounded,
                  color: _p1, size: 18)),
            const SizedBox(width: 12),
            const Expanded(child: Text('How does this analysis work?',
                style: TextStyle(color: _txt, fontSize: 13.5,
                    fontWeight: FontWeight.w600))),
            RotationTransition(turns: _rotate,
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _sub, size: 22)),
          ]),
        ),
      ),
      SizeTransition(
        sizeFactor: _expand,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            const Divider(color: _border, height: 1),
            const SizedBox(height: 14),
            _howRow('❤️', 'Heart Rate',
                'A resting rate of 60–80 bpm indicates your heart '
                'pumps efficiently. Higher rates can reflect stress or dehydration.'),
            const SizedBox(height: 10),
            _howRow('🌊', 'Blood Pressure',
                'Below 120/80 mmHg is optimal. Rising trends are flagged '
                'early so you can act before they become a problem.'),
            const SizedBox(height: 10),
            _howRow('📊', 'Heart Rate Variability',
                'HRV measures how your nervous system adapts. Higher HRV '
                'means better recovery, lower stress and good heart health.'),
            const SizedBox(height: 10),
            _howRow('🔗', 'Combined Analysis',
                'Looking at all three together gives a much fuller picture '
                'than any single measurement alone.'),
          ]),
        ),
      ),
    ]),
  );

  Widget _howRow(String emoji, String title, String body) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 10),
      Expanded(child: RichText(text: TextSpan(children: [
        TextSpan(text: '$title  ',
            style: const TextStyle(color: _txt, fontSize: 13,
                fontWeight: FontWeight.w700)),
        TextSpan(text: body,
            style: const TextStyle(color: _sub, fontSize: 12.5, height: 1.6)),
      ]))),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════
// DISCLAIMER
// ═════════════════════════════════════════════════════════════════
class _DisclaimerCard extends StatelessWidget {
  final String text;
  const _DisclaimerCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('⚕️', style: TextStyle(fontSize: 15)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(
          color: _sub, fontSize: 11.5, height: 1.6))),
    ]),
  );
}