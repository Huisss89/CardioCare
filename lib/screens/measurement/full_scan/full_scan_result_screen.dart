import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../widgets/bp_category_widgets.dart';
import '../../home/home_screen.dart';

class FullScanResultScreen extends StatelessWidget {
  final int hr;
  final double hrv;
  final int systolic;
  final int diastolic;
  final List<CameraDescription> cameras;

  const FullScanResultScreen({
    super.key,
    required this.hr,
    required this.hrv,
    required this.systolic,
    required this.diastolic,
    required this.cameras,
  });

  String _getHRCategory() {
    if (hr < 60) return 'Low';
    if (hr <= 100) return 'Normal';
    return 'High';
  }

  String _getHRVCategory() {
    if (hrv < 50) return 'Low';
    if (hrv <= 100) return 'Good';
    return 'Excellent';
  }

  String _getBPCategory() {
    if (systolic >= 180 || diastolic >= 120) return 'Hypertensive Crisis';
    if (systolic >= 140 || diastolic >= 90) return 'High BP Stage 2';
    if (systolic >= 130 || diastolic >= 80) return 'High BP Stage 1';
    if (systolic >= 120 && diastolic < 80) return 'Elevated';
    return 'Normal';
  }

  final List<Map<String, dynamic>> _bpCategories = const [
    {
      "title": "Normal",
      "range": "< 120 / < 80 mmHg",
      "details": "Ideal blood pressure. Keep maintaining a healthy lifestyle.",
      "color": Colors.green,
      "icon": Icons.check_circle_rounded,
    },
    {
      "title": "Elevated",
      "range": "120-129 / < 80 mmHg",
      "details":
          "BP slightly above normal. Monitor regularly and adopt healthier habits.",
      "color": Colors.orangeAccent,
      "icon": Icons.trending_up_rounded,
    },
    {
      "title": "Hypertension Stage 1",
      "range": "130-139 / 80-89 mmHg",
      "details": "Mild hypertension. Lifestyle changes are highly recommended.",
      "color": Colors.deepOrange,
      "icon": Icons.warning_amber_rounded,
    },
    {
      "title": "Hypertension Stage 2",
      "range": ">= 140 / >= 90 mmHg",
      "details":
          "High blood pressure. Medical consultation is strongly advised.",
      "color": Colors.redAccent,
      "icon": Icons.health_and_safety_rounded,
    },
    {
      "title": "Hypertensive Crisis",
      "range": ">= 180 / >= 120 mmHg",
      "details": "Seek immediate medical attention. This level is dangerous.",
      "color": Colors.red,
      "icon": Icons.dangerous_rounded,
    },
  ];

  String _getRecommendation() {
    if (hr < 60) {
      return 'Your heart rate is below normal. If you experience dizziness or fatigue, consult a doctor.';
    } else if (hr > 100) {
      return 'Your heart rate is elevated. Consider relaxation techniques and avoid caffeine. Consult a doctor if persistent.';
    } else if (hrv < 50) {
      return 'Low HRV may indicate stress. Try meditation, regular exercise, and adequate sleep.';
    } else {
      return 'Your readings look good! Maintain a healthy lifestyle with regular exercise and balanced diet.';
    }
  }

  String _getBPRecommendation() {
    // int systolic = widget.systolic;
    // int diastolic = widget.diastolic;

    if (systolic >= 180 || diastolic >= 120) {
      return 'URGENT: Hypertensive crisis detected! Seek immediate medical attention.';
    } else if (systolic >= 140 || diastolic >= 90) {
      return 'Stage 2 Hypertension detected. Please consult your doctor soon for proper treatment and management.';
    } else if (systolic >= 130 || diastolic >= 80) {
      return 'Stage 1 Hypertension detected. Consult your doctor about lifestyle changes and possible medication.';
    } else if (systolic >= 120 && diastolic < 80) {
      return 'Your BP is elevated. Focus on lifestyle changes: reduce sodium, exercise regularly, and manage stress.';
    } else {
      return 'Your blood pressure is normal. Maintain a healthy lifestyle with regular exercise and balanced diet.';
    }
  }

  bool _shouldSeekDoctor() {
    return systolic >= 140 || diastolic >= 90;
    //return widget.systolic >= 140 || widget.diastolic >= 90;
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String category,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(cameras: cameras),
            ),
            (route) => false,
          ),
        ),
        title: const Text(
          'Full Scan Results',
          style: TextStyle(color: Color(0xFF2D3748)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildMetricCard(
              title: 'Heart Rate',
              value: '$hr',
              unit: 'BPM',
              category: _getHRCategory(),
              icon: Icons.favorite_rounded,
              colors: const [Color(0xFFFF6B9D), Color(0xFFFFC3A0)],
            ),
            const SizedBox(height: 14),
            _buildMetricCard(
              title: 'Heart Rate Variability',
              value: hrv.toStringAsFixed(1),
              unit: 'ms',
              category: _getHRVCategory(),
              icon: Icons.show_chart_rounded,
              colors: const [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            const SizedBox(height: 14),
            _buildMetricCard(
              title: 'Blood Pressure',
              value: '$systolic/$diastolic',
              unit: 'mmHg',
              category: _getBPCategory(),
              icon: Icons.water_drop_rounded,
              colors: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
            ),
            const SizedBox(height: 20),
            _buildMeaningCard(
              title: 'Understand HR & HRV',
              icon: Icons.thumb_up_off_alt_sharp,
              iconColor: const Color(0xFFFF6B9D),
              children: const [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: Color(0xFFFF6B9D), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Heart Rate (HR):',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'The number of times your heart beats per minute (BPM). A resting HR between 60-100 BPM is normal.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF718096),
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.show_chart_rounded,
                        color: Color(0xFF667EEA), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Heart Rate Variability (HRV):',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'The minor fluctuations in the time intervals between successive heartbeats. The normal HRV range for healthy adults is 19-75 milliseconds. A higher HRV is a key indicator of a healthy, resilient nervous system, and is often associated with lower stress levels.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF718096),
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildMeaningCard(
              title: 'Understand Blood Pressure',
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF4FACFE),
              children: const [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        color: Color(0xFF4FACFE), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Systolic (top): Pressure when the heart pumps blood.',
                        style: TextStyle(color: Color(0xFF4A5568), height: 1.5),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        color: Color(0xFF00F2FE), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diastolic (bottom): Pressure when the heart relaxes between beats.',
                        style: TextStyle(color: Color(0xFF4A5568), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            CollapsibleCategorySection(categories: _bpCategories),
            const SizedBox(height: 24),

            // BP Recommendation Card
            if (_shouldSeekDoctor())
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF56565).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFF56565).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_rounded,
                        color: Color(0xFFF56565), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Medical Attention Needed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getBPRecommendation(),
                            style: const TextStyle(
                              color: Color(0xFF4A5568),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // General Recommendation Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFF667EEA).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Color(0xFF667EEA), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommendation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getRecommendation(),
                          style: const TextStyle(
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => HomeScreen(cameras: cameras),
                ),
                (route) => false,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Done',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
