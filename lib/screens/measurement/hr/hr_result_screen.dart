import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../utils/firestore_utils.dart';

class HRResultScreen extends StatelessWidget {
  final int hr;
  final double hrv;

  const HRResultScreen({super.key, required this.hr, required this.hrv});

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

  Color _getHRColor() {
    if (hr < 60) return const Color(0xFFED8936);
    if (hr <= 100) return const Color(0xFF48BB78);
    return const Color(0xFFF56565);
  }

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

// --- NEW: HR & HRV Information Card ---
  Widget _buildHRVInfoCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Understand Heart Rate & Heart Rate Variability',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748)),
          ),
          const SizedBox(height: 12),
          // HR Definition
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded,
                  color: Color(0xFFFF6B9D), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Heart Rate (HR):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Text(
                      'The number of times your heart beats per minute (BPM). A resting HR between 60-100 BPM is normal.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // HRV Definition
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.show_chart_rounded,
                  color: Color(0xFF667EEA), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Heart Rate Variability (HRV):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Text(
                      'The minor fluctuations in the time intervals between successive heartbeats. The normal HRV range for healthy adults is 19-75 milliseconds. A higher HRV is a key indicator of a healthy, resilient nervous system, and is often associated with lower stress levels.',
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

  Future<void> _saveReading() async {
    final Map<String, dynamic> readingData = {
      'hr': hr,
      'hrv': hrv,
      'date': DateTime.now().toIso8601String(),
      'type': 'HR/HRV',
    };

    // Save to Firestore db
    await saveReadingToFirestore(type: 'HR/HRV', data: readingData);

    // FIX: Save to local history using the logged-in user's email prefix
    final prefs = await SharedPreferences.getInstance();
    final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

    if (loggedInUserEmail.isNotEmpty) {
      final history =
          prefs.getStringList('${loggedInUserEmail}_hrHistory') ?? [];
      final reading = jsonEncode(readingData);
      history.insert(0, reading);
      await prefs.setStringList('${loggedInUserEmail}_hrHistory', history);
      print("HR Reading saved locally with prefix.");
    } else {
      print("HR Reading not saved locally: No loggedInUserEmail found.");
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
          'Heart Rate Results',
          style: TextStyle(color: Color(0xFF2D3748)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. MAIN HR CARD (existing code)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFFC3A0)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.favorite, size: 60, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Heart Rate',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$hr',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          ' BPM',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getHRCategory(),
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
            const SizedBox(height: 16),
            // 2. HRV CARD (existing code)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                  const Icon(Icons.show_chart,
                      size: 40, color: Color(0xFF667EEA)),
                  const SizedBox(height: 12),
                  const Text(
                    'Heart Rate Variability',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hrv.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFF2D3748),
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          ' ms',
                          style: TextStyle(
                            color: Color(0xFF718096),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getHRVCategory(),
                      style: const TextStyle(
                        color: Color(0xFF667EEA),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 3. HR/HRV INFO CARD (NEW POSITION)
            _buildHRVInfoCard(),
            const SizedBox(height: 24),
            // 4. RECOMMENDATION CARD (existing code)
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
            const SizedBox(height: 32),
            // 5. DONE BUTTON (existing code)
            GestureDetector(
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
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
