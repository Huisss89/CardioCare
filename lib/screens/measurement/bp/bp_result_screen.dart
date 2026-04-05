import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../widgets/bp_category_widgets.dart';
import '../../home/home_screen.dart';

class BPResultScreen extends StatefulWidget {
  final int systolic;
  final int diastolic;
  final List<CameraDescription> cameras;

  const BPResultScreen({
    super.key,
    required this.systolic,
    required this.diastolic,
    required this.cameras,
  });

  @override
  _BPResultScreenState createState() => _BPResultScreenState();
}

class _BPResultScreenState extends State<BPResultScreen> {
  String _getBPCategory(int systolic, int diastolic) {
    if (systolic >= 180 || diastolic >= 120) return 'Hypertensive Crisis';
    if (systolic >= 140 || diastolic >= 90) return 'High BP Stage 2';
    if (systolic >= 130 || diastolic >= 80) return 'High BP Stage 1';
    if (systolic >= 120 && diastolic < 80) return 'Elevated';
    return 'Normal';
  }

  Color _getBPColor(int systolic, int diastolic) {
    if (systolic >= 180 || diastolic >= 120) return const Color(0xFFF56565);
    if (systolic >= 140 || diastolic >= 90) return const Color(0xFFED8936);
    if (systolic >= 130 || diastolic >= 80) return const Color(0xFFECC94B);
    if (systolic >= 120 && diastolic < 80) return const Color(0xFFECC94B);
    return const Color(0xFF48BB78);
  }

  String _getRecommendation() {
    int systolic = widget.systolic;
    int diastolic = widget.diastolic;

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
    return widget.systolic >= 140 || widget.diastolic >= 90;
  }

  final List<Map<String, dynamic>> _bpCategories = [
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
      "details":
          "High blood pressure. Medical consultation is strongly advised.",
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showClassificationDialog(widget.systolic, widget.diastolic);
    });
  }

  Future<void> _showClassificationDialog(int systolic, int diastolic) async {
    if (!mounted) return;

    final category = _getBPCategory(systolic, diastolic);
    final color = _getBPColor(systolic, diastolic);
    final icon = category == 'Normal'
        ? Icons.check_circle_rounded
        : Icons.warning_rounded;

    String dialogTitle;
    String dynamicContent;
    String buttonText;

    if (category == 'Normal') {
      dialogTitle = 'Normal BP';
      dynamicContent =
          'Great news! Your estimated Blood Pressure of $systolic/$diastolic mmHg is in the healthy range. Keep up the good work!';
      buttonText = 'Awesome!';
    } else if (category == 'Elevated') {
      dialogTitle = 'Elevated BP';
      dynamicContent =
          'Attention: Your BP is elevated ($systolic/$diastolic mmHg). This is a warning sign. Focus on lifestyle adjustments now.';
      buttonText = 'Understood';
    } else if (category == 'High BP Stage 1') {
      dialogTitle = 'High BP Stage 1';
      dynamicContent =
          'Warning: Your BP is in Stage 1 Hypertension ($systolic/$diastolic mmHg). Lifestyle changes and doctor consultation are strongly recommended.';
      buttonText = 'Acknowledge';
    } else if (category == 'High BP Stage 2') {
      dialogTitle = 'High BP Stage 2';
      dynamicContent =
          'Serious Warning: Your BP is in Stage 2 Hypertension ($systolic/$diastolic mmHg). Please consult a healthcare professional immediately.';
      buttonText = 'Seek Advice';
    } else if (category == 'Hypertensive Crisis') {
      dialogTitle = '🚨 URGENT: CRISIS';
      dynamicContent =
          '🚨 URGENT: Your BP is critical ($systolic/$diastolic mmHg)! Seek emergency medical attention right now.';
      buttonText = 'Seek Advice';
    } else {
      dialogTitle = 'BP Classification';
      dynamicContent =
          'Your estimated BP is $systolic/$diastolic mmHg. Check the Category Guide below for details.';
      buttonText = 'OK';
    }

    dynamicContent +=
        '\n\nFor more information on BP categories and detailed trends, check the Trends & Analysis tab.';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(dialogTitle,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Text(
            dynamicContent,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.5, color: Color(0xFF4A5568)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(buttonText,
                style: const TextStyle(color: Color(0xFF667EEA))),
          ),
        ],
      ),
    );
  }

  Widget _buildBPDefinitionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5F7FA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Understanding Blood Pressure',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748)),
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_upward_rounded,
                  color: Color(0xFF4FACFE), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Systolic (Top Number):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Measures the pressure your blood is pushing against your artery walls when the heart beats.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
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
              Icon(Icons.arrow_downward_rounded,
                  color: Color(0xFF00F2FE), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diastolic (Bottom Number):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Measures the pressure your blood is pushing against your artery walls while the heart muscle rests between beats.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBPAccordionList() {
    return CollapsibleCategorySection(categories: _bpCategories);
  }

  Future<void> _saveReading() async {
    final Map<String, dynamic> readingData = {
      'systolic': widget.systolic,
      'diastolic': widget.diastolic,
      'date': DateTime.now().toIso8601String(),
      'type': 'BP_LOG',
    };

    final prefs = await SharedPreferences.getInstance();
    final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

    if (loggedInUserEmail.isNotEmpty) {
      final history =
          prefs.getStringList('${loggedInUserEmail}_bpHistory') ?? [];
      final reading = jsonEncode(readingData);
      history.insert(0, reading);
      await prefs.setStringList('${loggedInUserEmail}_bpHistory', history);
    }
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
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: const Text(
          'BP Results',
          style: TextStyle(color: Color(0xFF2D3748)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. BP ESTIMATION RESULT CARD
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4FACFE).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.water_drop, size: 60, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Blood Pressure',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.systolic}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 40,
                        ),
                      ),
                      Text(
                        '${widget.diastolic}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'mmHg',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getBPCategory(widget.systolic, widget.diastolic),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. WHAT IS BP CARD (Definition)
            _buildBPDefinitionCard(),
            const SizedBox(height: 24),

            // 3. BP CATEGORY ACCORDION LIST
            _buildBPAccordionList(),
            const SizedBox(height: 24),

            // 4. RECOMMENDATION CARD (Warning or general advice)
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
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF667EEA).withOpacity(0.2)),
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
            const SizedBox(height: 32),

            // 5. DONE BUTTON
            GestureDetector(
              onTap: () {
                // Navigate back to home screen explicitly instead of popping to first route
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      cameras: widget
                          .cameras, // You'll need to pass cameras to BPResultScreen
                    ),
                  ),
                  (route) => false,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
