import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Trend Screen
final List<Map<String, dynamic>> heartRateCategories = [
  {
    "title": "Bradycardia",
    "range": "< 60 bpm",
    "details": "Heart rate slower than normal. May cause dizziness or fatigue.",
    "color": Colors.blueAccent,
    "icon": Icons.arrow_downward_rounded,
  },
  {
    "title": "Normal",
    "range": "60 – 100 bpm",
    "details": "Healthy resting heart rate for most adults.",
    "color": Colors.green,
    "icon": Icons.favorite_rounded,
  },
  {
    "title": "Elevated",
    "range": "100 – 120 bpm",
    "details": "Slightly above normal. Monitor if persistent.",
    "color": Colors.orangeAccent,
    "icon": Icons.warning_amber_rounded,
  },
  {
    "title": "Tachycardia",
    "range": "> 120 bpm",
    "details": "Abnormally fast heart rate. Consider resting or checking BP.",
    "color": Colors.redAccent,
    "icon": Icons.trending_up_rounded,
  },
];

final List<Map<String, dynamic>> hrvCategories = [
  {
    "title": "Very Low HRV",
    "range": "< 30 ms",
    "details":
        "High stress levels, poor recovery. Prioritize rest and stress management.",
    "color": Colors.redAccent,
    "icon": Icons.sentiment_very_dissatisfied_rounded,
  },
  {
    "title": "Low HRV",
    "range": "30 – 50 ms",
    "details":
        "Room for improvement. Focus on sleep and relaxation techniques.",
    "color": Colors.orangeAccent,
    "icon": Icons.sentiment_dissatisfied_rounded,
  },
  {
    "title": "Good HRV",
    "range": "50 – 100 ms",
    "details":
        "Healthy HRV. Continue with regular exercise and balanced lifestyle.",
    "color": Colors.lightGreenAccent,
    "icon": Icons.sentiment_satisfied_rounded,
  },
  {
    "title": "Excellent HRV",
    "range": "> 100 ms",
    "details": "Outstanding recovery capacity and low stress levels.",
    "color": Colors.green,
    "icon": Icons.sentiment_very_satisfied_rounded,
  },
];

final List<Map<String, dynamic>> bpCategories = [
  {
    "title": "Normal",
    "range": "< 120 / < 80 mmHg",
    "details": "Ideal blood pressure. Keep maintaining a healthy lifestyle!",
    "color": Colors.green,
    "icon": Icons.check_circle_rounded,
  },
  {
    "title": "Elevated",
    "range": "120 – 129 / < 80 mmHg",
    "details":
        "BP slightly above normal. Monitor regularly and adopt healthier habits.",
    "color": Colors.orangeAccent,
    "icon": Icons.trending_up_rounded,
  },
  {
    "title": "Hypertension Stage 1",
    "range": "130 – 139 / 80 – 89 mmHg",
    "details": "Mild hypertension. Lifestyle changes are highly recommended.",
    "color": Colors.deepOrange,
    "icon": Icons.warning_amber_rounded,
  },
  {
    "title": "Hypertension Stage 2",
    "range": "≥ 140 / ≥ 90 mmHg",
    "details": "High blood pressure. Medical consultation is strongly advised.",
    "color": Colors.redAccent,
    "icon": Icons.health_and_safety_rounded,
  },
  {
    "title": "Hypertensive Crisis",
    "range": "≥ 180 / ≥ 120 mmHg",
    "details": "Seek immediate medical attention. This level is dangerous.",
    "color": Colors.red,
    "icon": Icons.dangerous_rounded,
  },
];

final List<Map<String, dynamic>> bpRecommendations = [
  {
    "title": "Reduce Salt Intake",
    "icon": Icons.no_food_rounded,
    "color": Colors.blueAccent,
    "desc": "Keep sodium under 1,500–2,300mg/day to lower BP naturally."
  },
  {
    "title": "Stay Active",
    "icon": Icons.fitness_center_rounded,
    "color": Colors.green,
    "desc": "Aim for 30 minutes of exercise at least 5 days a week."
  },
  {
    "title": "Manage Stress",
    "icon": Icons.self_improvement_rounded,
    "color": Colors.deepPurple,
    "desc": "Deep breathing, meditation, and quality sleep help regulate BP."
  },
  {
    "title": "Healthy Eating",
    "icon": Icons.restaurant_rounded,
    "color": Colors.orange,
    "desc": "Adopt a DASH-style diet: fruits, vegetables, whole grains."
  },
  {
    "title": "Limit Alcohol & Caffeine",
    "icon": Icons.local_drink_rounded,
    "color": Colors.teal,
    "desc": "Excessive consumption increases BP significantly."
  },
];

final List<Map<String, dynamic>> healthInsights = [
  {
    "title": "Blood Pressure Trend",
    "icon": Icons.show_chart_rounded,
    "color": Colors.indigo,
    "desc": "Your BP pattern over time helps detect hypertension earlier.",
  },
  {
    "title": "Heart Rate Variability",
    "icon": Icons.favorite_border_rounded,
    "color": Colors.deepPurple,
    "desc": "Higher HRV typically reflects better stress resilience.",
  },
  {
    "title": "Daily Heart Rate Pattern",
    "icon": Icons.favorite_rounded,
    "color": Colors.redAccent,
    "desc":
        "Monitor your resting, active, and peak heart rate throughout the day.",
  },
  {
    "title": "Stress Level Indicator",
    "icon": Icons.self_improvement_rounded,
    "color": Colors.teal,
    "desc": "HRV & HR combined estimate your daily stress load.",
  },
  {
    "title": "Lifestyle Recommendations",
    "icon": Icons.health_and_safety_rounded,
    "color": Colors.green,
    "desc": "Personalised tips based on HR & BP changes.",
  },
];

// ── Metric Definitions Data ──────────────────────────────────────────────────
class _MetricDefinition {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color gradientStart;
  final Color gradientEnd;
  final String whatIsIt;
  final String whyItMatters;
  final List<_DefinitionDetail> details;

  const _MetricDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.whatIsIt,
    required this.whyItMatters,
    required this.details,
  });
}

class _DefinitionDetail {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _DefinitionDetail({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
}

const _heartRateDefinition = _MetricDefinition(
  title: 'What is Heart Rate?',
  subtitle: 'Beats Per Minute (BPM)',
  icon: Icons.favorite_rounded,
  iconColor: Color(0xFFFF6B9D),
  gradientStart: Color(0xFFFF6B9D),
  gradientEnd: Color(0xFFFF8E53),
  whatIsIt:
      'Heart Rate (HR) is the number of times your heart beats per minute. It reflects how hard your heart is working to pump blood throughout your body.',
  whyItMatters:
      'Your resting heart rate is one of the most reliable indicators of cardiovascular health. A lower resting HR generally means your heart is more efficient and your fitness level is higher.',
  details: [
    _DefinitionDetail(
      icon: Icons.arrow_downward_rounded,
      color: Color(0xFF4299E1),
      label: 'Bradycardia',
      value: '< 60 BPM',
    ),
    _DefinitionDetail(
      icon: Icons.check_circle_rounded,
      color: Color(0xFF48BB78),
      label: 'Normal Range',
      value: '60–100 BPM',
    ),
    _DefinitionDetail(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFED8936),
      label: 'Elevated',
      value: '100–120 BPM',
    ),
    _DefinitionDetail(
      icon: Icons.trending_up_rounded,
      color: Color(0xFFF56565),
      label: 'Tachycardia',
      value: '> 120 BPM',
    ),
  ],
);

const _hrvDefinition = _MetricDefinition(
  title: 'What is HRV?',
  subtitle: 'Heart Rate Variability (ms)',
  icon: Icons.show_chart_rounded,
  iconColor: Color(0xFF667EEA),
  gradientStart: Color(0xFF667EEA),
  gradientEnd: Color(0xFF764BA2),
  whatIsIt:
      'Heart Rate Variability (HRV) measures the tiny fluctuations in time between consecutive heartbeats (in milliseconds). Unlike HR which counts beats, HRV looks at the rhythm variation between them.',
  whyItMatters:
      'HRV is a window into your autonomic nervous system. A higher HRV means your body can adapt well to stress, recover faster, and handle physical and mental demands more effectively.',
  details: [
    _DefinitionDetail(
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFFF56565),
      label: 'Very Low',
      value: '< 30 ms',
    ),
    _DefinitionDetail(
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFFED8936),
      label: 'Low',
      value: '30–50 ms',
    ),
    _DefinitionDetail(
      icon: Icons.sentiment_satisfied_rounded,
      color: Color(0xFF48BB78),
      label: 'Good',
      value: '50–100 ms',
    ),
    _DefinitionDetail(
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFF00C896),
      label: 'Excellent',
      value: '> 100 ms',
    ),
  ],
);

const _estimatedBpDefinition = _MetricDefinition(
  title: 'What is Estimated BP?',
  subtitle: 'Camera-Based Estimation (mmHg)',
  icon: Icons.camera_alt_rounded,
  iconColor: Color(0xFF4FACFE),
  gradientStart: Color(0xFF4FACFE),
  gradientEnd: Color(0xFF00F2FE),
  whatIsIt:
      'Estimated Blood Pressure is derived from your camera-based pulse readings using photoplethysmography (PPG). It analyses subtle colour changes in your fingertip to estimate systolic and diastolic pressure.',
  whyItMatters:
      'While not a replacement for a clinical cuff, estimated BP helps you track trends over time and notice patterns — especially useful between formal medical check-ups.',
  details: [
    _DefinitionDetail(
      icon: Icons.check_circle_rounded,
      color: Color(0xFF48BB78),
      label: 'Normal',
      value: '< 120/80',
    ),
    _DefinitionDetail(
      icon: Icons.trending_up_rounded,
      color: Color(0xFFED8936),
      label: 'Elevated',
      value: '120–129/<80',
    ),
    _DefinitionDetail(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFED8936),
      label: 'Stage 1 HTN',
      value: '130–139/80–89',
    ),
    _DefinitionDetail(
      icon: Icons.dangerous_rounded,
      color: Color(0xFFF56565),
      label: 'Stage 2 HTN',
      value: '≥ 140/90',
    ),
  ],
);

const _recordedBpDefinition = _MetricDefinition(
  title: 'What is Recorded BP?',
  subtitle: 'Manual Log — Cuff Reading (mmHg)',
  icon: Icons.edit_note_rounded,
  iconColor: Color(0xFF9F7AEA),
  gradientStart: Color(0xFF9F7AEA),
  gradientEnd: Color(0xFF667EEA),
  whatIsIt:
      'Recorded Blood Pressure is data you manually enter from a physical blood pressure cuff (sphygmomanometer). This is the clinical gold standard for measuring BP — two numbers: Systolic (top) and Diastolic (bottom).',
  whyItMatters:
      'Manual cuff readings are the most accurate way to monitor blood pressure at home. Logging them regularly helps you and your doctor identify hypertension trends, medication effectiveness, and lifestyle impact.',
  details: [
    _DefinitionDetail(
      icon: Icons.arrow_upward_rounded,
      color: Color(0xFF4FACFE),
      label: 'Systolic',
      value: 'Top number (mmHg)',
    ),
    _DefinitionDetail(
      icon: Icons.arrow_downward_rounded,
      color: Color(0xFF00F2FE),
      label: 'Diastolic',
      value: 'Bottom number (mmHg)',
    ),
    _DefinitionDetail(
      icon: Icons.check_circle_rounded,
      color: Color(0xFF48BB78),
      label: 'Healthy Target',
      value: '< 120/80 mmHg',
    ),
    _DefinitionDetail(
      icon: Icons.dangerous_rounded,
      color: Color(0xFFF56565),
      label: 'Crisis Level',
      value: '≥ 180/120 mmHg',
    ),
  ],
);
// ─────────────────────────────────────────────────────────────────────────────

// Enum for filter selection
enum MetricFilter { heartRate, hrv, estimatedBp, recordedBp }

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  List<Map<String, dynamic>> _bpReadings = [];
  List<Map<String, dynamic>> _hrReadings = [];

  // Filtered views for charts & stats
  List<Map<String, dynamic>> _filteredBpReadings = [];
  List<Map<String, dynamic>> _filteredHrReadings = [];

  // Global date selection (slider + range)
  late DateTime _anchorDate; // currently selected day
  late DateTime _visibleWeekStart; // first day shown in the slider
  String _rangeQuickFilter = '7d'; // 7d, 30d, all
  bool _isFilterExpanded = false; // Controls expandable filter box

  // New: Selected metric filter
  MetricFilter _selectedMetric = MetricFilter.heartRate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _anchorDate = DateTime(today.year, today.month, today.day);
    _visibleWeekStart =
        _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
    _loadData();
  }

  double? _safeParseHRV(dynamic hrvValue) {
    if (hrvValue == null) return null;
    try {
      if (hrvValue is double) return hrvValue;
      if (hrvValue is int) return hrvValue.toDouble();
      if (hrvValue is String) return double.tryParse(hrvValue);
      return null;
    } catch (e) {
      debugPrint('Error parsing HRV value: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

    final hrHistory = loggedInUserEmail.isNotEmpty
        ? prefs.getStringList('${loggedInUserEmail}_hrHistory') ?? []
        : prefs.getStringList('hrHistory') ?? [];

    final bpHistory = loggedInUserEmail.isNotEmpty
        ? prefs.getStringList('${loggedInUserEmail}_bpHistory') ?? []
        : prefs.getStringList('bpHistory') ?? [];

    List<Map<String, dynamic>> hrData = [];
    List<Map<String, dynamic>> bpData = [];

    for (var reading in hrHistory) {
      hrData.add(jsonDecode(reading));
    }
    for (var reading in bpHistory) {
      bpData.add(jsonDecode(reading));
    }

    hrData.sort((a, b) =>
        DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    bpData.sort((a, b) =>
        DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    if (mounted) {
      setState(() {
        _hrReadings = hrData;
        _bpReadings = bpData;
        _applyGlobalFilter();
      });
    }
  }

  void _applyGlobalFilter() {
    List<Map<String, dynamic>> bpData =
        List<Map<String, dynamic>>.from(_bpReadings);
    List<Map<String, dynamic>> hrData =
        List<Map<String, dynamic>>.from(_hrReadings);

    if (_rangeQuickFilter == '7d' || _rangeQuickFilter == '30d') {
      final days = _rangeQuickFilter == '7d' ? 7 : 30;
      final end = DateTime(
          _anchorDate.year, _anchorDate.month, _anchorDate.day, 23, 59, 59);
      final start = end.subtract(Duration(days: days - 1));

      bool within(DateTime? d) =>
          d != null && !d.isBefore(start) && !d.isAfter(end);

      bpData = bpData.where((r) {
        final date = DateTime.tryParse(r['date'] as String? ?? '');
        return within(date);
      }).toList();

      hrData = hrData.where((r) {
        final date = DateTime.tryParse(r['date'] as String? ?? '');
        return within(date);
      }).toList();
    }

    setState(() {
      _filteredBpReadings = bpData;
      _filteredHrReadings = hrData;
    });
  }

  void _moveWeek(int offset) {
    setState(() {
      _visibleWeekStart = _visibleWeekStart.add(Duration(days: 7 * offset));
      _anchorDate = _visibleWeekStart;
    });
    _applyGlobalFilter();
  }

  void _selectAnchor(DateTime day) {
    setState(() {
      _anchorDate = DateTime(day.year, day.month, day.day);
      _visibleWeekStart =
          _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
    });
    _applyGlobalFilter();
  }

  String _getAnalysisForMetric() {
    switch (_selectedMetric) {
      case MetricFilter.heartRate:
        return _getHeartRateAnalysis();
      case MetricFilter.hrv:
        return _getHRVAnalysis();
      case MetricFilter.estimatedBp:
        return _getBPAnalysis(_filteredBpReadings
            .where((r) => (r['type'] as String? ?? 'BP') != 'BP_LOG')
            .toList());
      case MetricFilter.recordedBp:
        return _getBPAnalysis(_filteredBpReadings
            .where((r) => (r['type'] as String? ?? 'BP') == 'BP_LOG')
            .toList());
    }
  }

  String _getHeartRateAnalysis() {
    if (_filteredHrReadings.length < 3) {
      return 'Not enough data for analysis. Start taking measurements to see trends and get personalized insights.';
    }
    List<String> insights = [];
    final recent =
        _filteredHrReadings.skip(_filteredHrReadings.length - 3).toList();
    final avgHR =
        (recent.map((r) => r['hr'] as int).reduce((a, b) => a + b) / 3);

    if (avgHR < 60) {
      insights.add('💙 Low Heart Rate (Bradycardia)\n'
          'Your average resting HR is ${avgHR.round()} BPM. '
          'If you\'re an athlete, this is normal. Otherwise:\n'
          '• Monitor for dizziness or fatigue\n'
          '• Check for underlying conditions\n'
          '• Consult doctor if experiencing symptoms\n'
          '• Review medications');
    } else if (avgHR > 100) {
      insights.add('❤️ Elevated Heart Rate (Tachycardia)\n'
          'Your average resting HR is ${avgHR.round()} BPM, which is high. '
          'Consider:\n'
          '• Reducing caffeine intake\n'
          '• Managing stress and anxiety\n'
          '• Improving sleep quality\n'
          '• Staying hydrated\n'
          '• Avoiding stimulants\n'
          '• Consulting a doctor if persistent');
    } else if (avgHR > 90) {
      insights.add('💓 Slightly Elevated Heart Rate\n'
          'Your average resting HR is ${avgHR.round()} BPM. '
          'This is on the higher side of normal. Tips:\n'
          '• Practice deep breathing exercises\n'
          '• Regular aerobic exercise\n'
          '• Reduce caffeine consumption\n'
          '• Ensure 7-9 hours of sleep\n'
          '• Manage stress levels');
    } else {
      insights.add('✅ Healthy Heart Rate\n'
          'Your average resting HR is ${avgHR.round()} BPM. '
          'This is excellent! A normal resting heart rate indicates:\n'
          '• Good cardiovascular fitness\n'
          '• Proper heart function\n'
          '• Effective recovery\n'
          'Keep maintaining your healthy lifestyle!');
    }
    return insights.join('\n\n━━━━━━━━━━━━━━━━━━━━\n\n');
  }

  String _getHRVAnalysis() {
    if (_filteredHrReadings.length < 3) {
      return 'Not enough data for analysis. Start taking measurements to see trends and get personalized insights.';
    }
    List<String> insights = [];
    final recent =
        _filteredHrReadings.skip(_filteredHrReadings.length - 3).toList();
    final hrvRaw = recent.map((r) => r['hrv']).toList();
    final hrvValues = hrvRaw
        .map((v) => v is num ? v.toDouble() : null)
        .whereType<double>()
        .toList();

    if (hrvValues.isEmpty) {
      return 'Not enough HRV data available. Ensure your device is collecting HRV measurements.';
    }

    final avgHRV = (hrvValues.reduce((a, b) => a + b) / hrvValues.length);

    if (avgHRV < 30) {
      insights.add('⚠️ Very Low Heart Rate Variability\n'
          'Your average HRV is ${avgHRV.round()} ms, which is quite low. '
          'This may indicate:\n'
          '• High stress levels\n'
          '• Poor recovery\n'
          '• Overtraining\n'
          '• Insufficient sleep\n'
          'Action steps:\n'
          '• Prioritize 7-9 hours of quality sleep\n'
          '• Practice stress management (meditation, yoga)\n'
          '• Reduce training intensity\n'
          '• Consider adaptogenic supplements\n'
          '• Consult healthcare provider');
    } else if (avgHRV < 50) {
      insights.add('💤 Low Heart Rate Variability\n'
          'Your average HRV is ${avgHRV.round()} ms. '
          'Room for improvement:\n'
          '• Focus on sleep quality\n'
          '• Reduce alcohol consumption\n'
          '• Practice daily meditation (10-15 min)\n'
          '• Stay consistent with exercise\n'
          '• Manage work-life balance\n'
          '• Consider recovery days');
    } else if (avgHRV < 100) {
      insights.add('😊 Good Heart Rate Variability\n'
          'Your average HRV is ${avgHRV.round()} ms. '
          'This is healthy! To maintain or improve:\n'
          '• Continue regular exercise\n'
          '• Maintain consistent sleep schedule\n'
          '• Practice relaxation techniques\n'
          '• Stay hydrated\n'
          '• Balanced nutrition');
    } else {
      insights.add('⭐ Excellent Heart Rate Variability!\n'
          'Your average HRV is ${avgHRV.round()} ms. Outstanding! '
          'This indicates:\n'
          '• Excellent recovery capacity\n'
          '• Low stress levels\n'
          '• Good cardiovascular health\n'
          '• Optimal nervous system function\n'
          'You\'re doing everything right!');
    }
    return insights.join('\n\n━━━━━━━━━━━━━━━━━━━━\n\n');
  }

  String _getBPAnalysis(List<Map<String, dynamic>> bpReadings) {
    if (bpReadings.length < 3) {
      return 'Not enough data for analysis. Start taking measurements to see trends and get personalized insights.';
    }
    List<String> insights = [];
    final recent = bpReadings.skip(bpReadings.length - 3).toList();
    final avgSystolic =
        (recent.map((r) => r['systolic'] as int).reduce((a, b) => a + b) / 3);
    final avgDiastolic =
        (recent.map((r) => r['diastolic'] as int).reduce((a, b) => a + b) / 3);

    if (avgSystolic >= 180 || avgDiastolic >= 120) {
      insights.add('🚨 URGENT: Hypertensive Crisis Detected!\n'
          'Your average BP is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
          'This is extremely high and requires immediate medical attention. '
          'Please contact your doctor or visit emergency care immediately.');
    } else if (avgSystolic >= 140 || avgDiastolic >= 90) {
      insights.add('⚠️ High Blood Pressure (Stage 2)\n'
          'Your average BP is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
          'This indicates Stage 2 Hypertension. Please consult your doctor for proper treatment. '
          'Medication may be necessary along with lifestyle changes.');
    } else if (avgSystolic >= 130 || avgDiastolic >= 80) {
      insights.add('⚠️ High Blood Pressure (Stage 1)\n'
          'Your average BP is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
          'This is in the hypertension range. Consider:\n'
          '• Reducing sodium intake (< 2,300mg/day)\n'
          '• Regular exercise (30 min, 5 days/week)\n'
          '• Weight management\n'
          '• Limiting alcohol\n'
          '• Consulting your doctor');
    } else if (avgSystolic >= 120) {
      insights.add('⚡ Elevated Blood Pressure\n'
          'Your average BP is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
          'While not yet hypertension, this is elevated. Take action now:\n'
          '• Monitor BP regularly\n'
          '• Reduce salt and processed foods\n'
          '• Increase physical activity\n'
          '• Manage stress through meditation\n'
          '• Maintain healthy weight');
    } else {
      insights.add('✅ Excellent Blood Pressure!\n'
          'Your average BP is ${avgSystolic.round()}/${avgDiastolic.round()} mmHg. '
          'This is in the healthy range. Keep up the good work!\n'
          '• Continue regular exercise\n'
          '• Maintain balanced diet\n'
          '• Keep monitoring regularly\n'
          '• Stay hydrated');
    }
    return insights.join('\n\n━━━━━━━━━━━━━━━━━━━━\n\n');
  }

  // ── NEW: Metric Definition Card ──────────────────────────────────────────
  Widget _buildMetricDefinitionCard() {
    _MetricDefinition def;
    switch (_selectedMetric) {
      case MetricFilter.heartRate:
        def = _heartRateDefinition;
        break;
      case MetricFilter.hrv:
        def = _hrvDefinition;
        break;
      case MetricFilter.estimatedBp:
        def = _estimatedBpDefinition;
        break;
      case MetricFilter.recordedBp:
        def = _recordedBpDefinition;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: def.gradientStart.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Banner ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [def.gradientStart, def.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(def.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          def.subtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── What Is It ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [def.gradientStart, def.gradientEnd],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'What is it?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  def.whatIsIt,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A5568),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Why It Matters ───────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [def.gradientStart, def.gradientEnd],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Why it matters?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: def.gradientStart.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: def.gradientStart.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: def.gradientStart, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          def.whyItMatters,
                          style: TextStyle(
                            fontSize: 13,
                            color: def.gradientStart
                                .withOpacity(0.9)
                                .withRed((def.gradientStart.red * 0.6).round()),
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Quick Reference Grid ─────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [def.gradientStart, def.gradientEnd],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Quick Reference',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: def.details.map((detail) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: detail.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: detail.color.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(detail.icon, color: detail.color, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  detail.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: detail.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  detail.value,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF718096),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTrendChart(List<Map<String, dynamic>> data, String type) {
    final displayData =
        data.length > 7 ? data.skip(data.length - 7).toList() : data;

    if (displayData.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('No data available')),
      );
    }

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayData.asMap().entries.map((entry) {
                final reading = entry.value;
                double value;
                int? systolic;
                int? diastolic;
                double maxValue;

                if (type == 'BP') {
                  systolic = reading['systolic'] as int?;
                  diastolic = reading['diastolic'] as int?;
                  value = (systolic?.toDouble() ?? 0);
                  maxValue = 160;
                } else if (type == 'HRV') {
                  final hrvDouble = _safeParseHRV(reading['hrv']);
                  value = hrvDouble ?? 0;
                  maxValue = 150;
                } else {
                  value = (reading['hr'] as int).toDouble();
                  maxValue = 120;
                }

                final height = (value / maxValue * 100).clamp(20.0, 100.0);

                Color getColor() {
                  if (type == 'BP') {
                    return value < 120
                        ? const Color(0xFF48BB78)
                        : value < 140
                            ? const Color(0xFFED8936)
                            : const Color(0xFFF56565);
                  } else if (type == 'HRV') {
                    return value < 30
                        ? const Color(0xFFF56565)
                        : value < 50
                            ? const Color(0xFFED8936)
                            : value < 100
                                ? const Color(0xFF48BB78)
                                : const Color(0xFF00C896);
                  } else {
                    return value < 60
                        ? const Color(0xFFED8936)
                        : value <= 100
                            ? const Color(0xFF48BB78)
                            : const Color(0xFFF56565);
                  }
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 40,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (type == 'BP' &&
                                  systolic != null &&
                                  diastolic != null)
                                Text(
                                  systolic.toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                    height: 1,
                                  ),
                                )
                              else
                                Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                    height: 1,
                                  ),
                                ),
                              if (type == 'BP' && diastolic != null)
                                Text(
                                  diastolic.toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF718096),
                                    height: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  getColor().withOpacity(0.7),
                                  getColor()
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBPStats(List<Map<String, dynamic>> bpData) {
    if (bpData.isEmpty) return const SizedBox.shrink();

    final systolicValues = bpData.map((r) => r['systolic'] as int).toList();
    final diastolicValues = bpData.map((r) => r['diastolic'] as int).toList();

    final avgSystolic =
        (systolicValues.reduce((a, b) => a + b) / systolicValues.length)
            .round();
    final avgDiastolic =
        (diastolicValues.reduce((a, b) => a + b) / diastolicValues.length)
            .round();
    final minSystolic = systolicValues.reduce((a, b) => a < b ? a : b);
    final maxSystolic = systolicValues.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Average', '$avgSystolic/$avgDiastolic',
                const Color(0xFF4FACFE)),
            _buildStatItem('Lowest', '$minSystolic', const Color(0xFF48BB78)),
            _buildStatItem('Highest', '$maxSystolic', const Color(0xFFF56565)),
          ],
        ),
      ],
    );
  }

  Widget _buildHRStats() {
    if (_filteredHrReadings.isEmpty) return const SizedBox.shrink();

    final hrValues = _filteredHrReadings.map((r) => r['hr'] as int).toList();
    final hrvRaw = _filteredHrReadings.map((r) => r['hrv']).toList();
    final hrvValues =
        hrvRaw.map((v) => _safeParseHRV(v)).whereType<double>().toList();

    final avgHR = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
    final int? avgHRV = hrvValues.isNotEmpty
        ? (hrvValues.reduce((a, b) => a + b) / hrvValues.length).round()
        : null;
    final minHR = hrValues.reduce((a, b) => a < b ? a : b);
    final maxHR = hrValues.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Avg HR', '$avgHR', const Color(0xFFFF6B9D)),
            _buildStatItem('Avg HRV', avgHRV != null ? '$avgHRV' : '-',
                const Color(0xFF667EEA)),
            _buildStatItem('Range', '$minHR-$maxHR', const Color(0xFF4FACFE)),
          ],
        ),
      ],
    );
  }

  Widget _buildHRVStats() {
    if (_filteredHrReadings.isEmpty) return const SizedBox.shrink();

    final hrvRaw = _filteredHrReadings.map((r) => r['hrv']).toList();
    final hrvValues = hrvRaw
        .map((v) => v is num ? v.toDouble() : null)
        .whereType<double>()
        .toList();

    if (hrvValues.isEmpty) return const SizedBox.shrink();

    final avgHRV = (hrvValues.reduce((a, b) => a + b) / hrvValues.length);
    final minHRV = hrvValues.reduce((a, b) => a < b ? a : b);
    final maxHRV = hrvValues.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
                'Avg HRV', '${avgHRV.round()}', const Color(0xFF667EEA)),
            _buildStatItem(
                'Lowest', '${minHRV.round()}', const Color(0xFF48BB78)),
            _buildStatItem(
                'Highest', '${maxHRV.round()}', const Color(0xFFF56565)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
      ],
    );
  }

  Widget _buildGeneralRecommendationsCard() {
    final tips = [
      {
        "icon": Icons.fitness_center_rounded,
        "text": "Be active for at least 30 minutes daily."
      },
      {
        "icon": Icons.restaurant_rounded,
        "text": "Reduce salt & avoid heavily processed foods."
      },
      {
        "icon": Icons.monitor_heart_rounded,
        "text": "Monitor BP regularly and track changes."
      },
      {
        "icon": Icons.self_improvement_rounded,
        "text": "Manage stress with breathing or relaxation."
      },
      {
        "icon": Icons.smoke_free_rounded,
        "text": "Avoid smoking & limit alcohol intake."
      },
      {
        "icon": Icons.scale_rounded,
        "text": "Maintain a healthy weight & lifestyle."
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.pinkAccent.shade100.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "General Health Recommendations",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...tips.map((t) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Icon(t["icon"] as IconData, size: 26, color: Colors.blueGrey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t["text"] as String,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryGuideForMetric() {
    List<Map<String, dynamic>> categories;
    String title;

    switch (_selectedMetric) {
      case MetricFilter.heartRate:
        categories = heartRateCategories;
        title = 'Heart Rate Categories';
        break;
      case MetricFilter.hrv:
        categories = hrvCategories;
        title = 'HRV Categories';
        break;
      case MetricFilter.estimatedBp:
      case MetricFilter.recordedBp:
        categories = bpCategories;
        title = 'Blood Pressure Categories';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedMetric == MetricFilter.heartRate)
          _buildHRCategoryGuide(categories)
        else if (_selectedMetric == MetricFilter.hrv)
          _buildHRVCategoryGuide(categories)
        else
          _buildBPCategoryGuide(categories),
      ],
    );
  }

  Widget _buildBPCategoryGuide(List<Map<String, dynamic>> categories) {
    return Column(
      children: categories.reversed.toList().map((cat) {
        return _buildBPCategoryCard(
          title: cat['title'] as String,
          range: cat['range'] as String,
          details: cat['details'] as String,
          color: cat['color'] as Color,
          icon: cat['icon'] as IconData,
        );
      }).toList(),
    );
  }

  Widget _buildBPCategoryCard({
    required String title,
    required String range,
    required String details,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          range,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF4A5568),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHRCategoryGuide(List<Map<String, dynamic>> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _buildHRGridCard(
          title: cat['title'] as String,
          range: cat['range'] as String,
          details: cat['details'] as String,
          color: cat['color'] as Color,
          icon: cat['icon'] as IconData,
        );
      },
    );
  }

  Widget _buildHRVCategoryGuide(List<Map<String, dynamic>> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _buildHRGridCard(
          title: cat['title'] as String,
          range: cat['range'] as String,
          details: cat['details'] as String,
          color: cat['color'] as Color,
          icon: cat['icon'] as IconData,
        );
      },
    );
  }

  Widget _buildHRGridCard({
    required String title,
    required String range,
    required String details,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 1,
            child: Text(
              title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              range,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: Text(
              details,
              style: const TextStyle(
                  fontSize: 11, height: 1.3, color: Color(0xFF4A5568)),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMetricButton(
              'Heart Rate', Icons.favorite_rounded, MetricFilter.heartRate),
          const SizedBox(width: 8),
          _buildMetricButton(
              'HRV', Icons.favorite_border_rounded, MetricFilter.hrv),
          const SizedBox(width: 8),
          _buildMetricButton('Estimated BP', Icons.trending_up_rounded,
              MetricFilter.estimatedBp),
          const SizedBox(width: 8),
          _buildMetricButton('Recorded BP', Icons.check_circle_rounded,
              MetricFilter.recordedBp),
        ],
      ),
    );
  }

  Widget _buildMetricButton(String label, IconData icon, MetricFilter filter) {
    final isSelected = _selectedMetric == filter;
    return Material(
      child: Ink(
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)])
              : LinearGradient(colors: [
                  const Color(0xFFE2E8F0).withOpacity(0.6),
                  const Color(0xFFCBD5E0).withOpacity(0.6),
                ]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => setState(() => _selectedMetric = filter),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF4A5568)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableFilter() {
    final anchorLabel = _anchorDate.toShortLabel();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: Color(0xFF667EEA), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        if (!_isFilterExpanded)
                          Text(
                            '$anchorLabel  •  ${_rangeQuickFilter == '7d' ? '7 days' : _rangeQuickFilter == '30d' ? '30 days' : 'All'}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF718096)),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isFilterExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF718096)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildDateSlider(),
                  const SizedBox(height: 16),
                  _buildGlobalRangeChips(),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasData = false;
    Widget trendChartWidget = const SizedBox.shrink();
    Widget statsWidget = const SizedBox.shrink();
    String trendTitle = '';

    switch (_selectedMetric) {
      case MetricFilter.heartRate:
        hasData = _filteredHrReadings.isNotEmpty;
        trendChartWidget = _buildTrendChart(_filteredHrReadings, 'HR');
        statsWidget = _buildHRStats();
        trendTitle = 'Heart Rate Trend';
        break;
      case MetricFilter.hrv:
        hasData = _filteredHrReadings.isNotEmpty;
        trendChartWidget = _buildTrendChart(_filteredHrReadings, 'HRV');
        statsWidget = _buildHRVStats();
        trendTitle = 'Heart Rate Variability Trend';
        break;
      case MetricFilter.estimatedBp:
        final estimatedBps = _filteredBpReadings
            .where((r) => (r['type'] as String? ?? 'BP') != 'BP_LOG')
            .toList();
        hasData = estimatedBps.isNotEmpty;
        trendChartWidget = _buildTrendChart(estimatedBps, 'BP');
        statsWidget = _buildBPStats(estimatedBps);
        trendTitle = 'BP Estimation Trend';
        break;
      case MetricFilter.recordedBp:
        final recordedBps = _filteredBpReadings
            .where((r) => (r['type'] as String? ?? 'BP') == 'BP_LOG')
            .toList();
        hasData = recordedBps.isNotEmpty;
        trendChartWidget = _buildTrendChart(recordedBps, 'BP');
        statsWidget = _buildBPStats(recordedBps);
        trendTitle = 'Recorded Blood Pressure Trend';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trends & Analysis',
          style:
              TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expandable Filter Box
            _buildExpandableFilter(),
            const SizedBox(height: 24),

            // Metric Filter Buttons
            const Text(
              'Select Metric',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF718096),
              ),
            ),
            const SizedBox(height: 12),
            _buildMetricFilterButtons(),
            const SizedBox(height: 28),

            // ── METRIC DEFINITION CARD (always visible, above everything) ──
            _buildMetricDefinitionCard(),
            const SizedBox(height: 28),

            // Trend Chart
            if (hasData) ...[
              Text(
                trendTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  children: [
                    trendChartWidget,
                    const SizedBox(height: 16),
                    statsWidget,
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Categories Guide
              _buildCategoryGuideForMetric(),
              const SizedBox(height: 32),
            ],

            // Health Insights
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_rounded,
                          color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Health Insights',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getAnalysisForMetric(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (hasData) _buildGeneralRecommendationsCard(),
            if (!hasData)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Icon(Icons.trending_up,
                        size: 100, color: const Color(0xFFCBD5E0)),
                    const SizedBox(height: 16),
                    const Text(
                      'No trend data available',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Take at least 3 measurements to see trends',
                      style: TextStyle(color: Color(0xFFA0AEC0)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

extension on DateTime {
  String toShortLabel() {
    const months = [
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
    final day = this.day.toString().padLeft(2, '0');
    final monthName = months[this.month - 1];
    return '$day $monthName $year';
  }
}

extension _RangeLabelHelpers on _TrendsScreenState {
  Widget _buildDateSlider() {
    final daysOfWeek = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final monthLabel =
        _anchorDate.toShortLabel().split(' ').sublist(1).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthYearSelector(monthLabel),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _moveWeek(-1),
            ),
            Column(
              children: [
                Text(
                  monthLabel,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a day to center the range',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _moveWeek(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayDate = _visibleWeekStart.add(Duration(days: index));
            final isSelected = dayDate.year == _anchorDate.year &&
                dayDate.month == _anchorDate.month &&
                dayDate.day == _anchorDate.day;
            final weekdayLabel = daysOfWeek[dayDate.weekday - 1];
            final dayNumber = dayDate.day.toString();

            return Expanded(
              child: GestureDetector(
                onTap: () => _selectAnchor(dayDate),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00C896)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        weekdayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          dayNumber,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF00C896)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMonthYearSelector(String monthLabel) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {});
                _showMonthYearPicker();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF667EEA), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.expand_more_rounded,
                        color: Color(0xFF718096), size: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMonthYearPicker() async {
    final today = DateTime.now();
    int selectedYear = _anchorDate.year;
    int selectedMonth = _anchorDate.month;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Month & Year',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Year',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF718096),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (selectedYear > today.year - 5)
                                        selectedYear--;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.remove_rounded,
                                        color: Color(0xFF667EEA)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    selectedYear.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (selectedYear < today.year + 5)
                                        selectedYear++;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        color: Color(0xFF667EEA)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Month',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF718096),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              const months = [
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
                                'Dec'
                              ];
                              final month = index + 1;
                              final isSelected = selectedMonth == month;

                              return GestureDetector(
                                onTap: () =>
                                    setModalState(() => selectedMonth = month),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF667EEA)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF667EEA)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    months[index],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF2D3748),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final firstDayOfMonth =
                              DateTime(selectedYear, selectedMonth, 1);
                          _selectAnchor(firstDayOfMonth);
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Apply',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlobalRangeChips() {
    return Row(
      children: [
        _buildRangeChip(
          label: '7 days',
          selected: _rangeQuickFilter == '7d',
          onTap: () {
            setState(() => _rangeQuickFilter = '7d');
            _applyGlobalFilter();
          },
        ),
        const SizedBox(width: 8),
        _buildRangeChip(
          label: '30 days',
          selected: _rangeQuickFilter == '30d',
          onTap: () {
            setState(() => _rangeQuickFilter = '30d');
            _applyGlobalFilter();
          },
        ),
      ],
    );
  }

  Widget _buildRangeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : const Color(0xFF4A5568),
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF667EEA),
      backgroundColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }
}
