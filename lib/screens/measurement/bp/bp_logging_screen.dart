import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../../../../utils/firestore_utils.dart';

class BPLoggingScreen extends StatefulWidget {
  const BPLoggingScreen({super.key});

  @override
  _BPLoggingScreenState createState() => _BPLoggingScreenState();
}

class _BPLoggingScreenState extends State<BPLoggingScreen> {
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- Network Check Helper ---
  Future<bool> _hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // --- Show No Internet Dialog ---
  Future<void> _showNoInternetDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFF56565), size: 26),
            SizedBox(width: 10),
            Text(
              'No Internet Connection',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your blood pressure reading could not be saved because you are currently offline.',
              style: TextStyle(
                color: Color(0xFF4A5568),
                height: 1.5,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Please check your internet connection and try again.',
              style: TextStyle(
                color: Color(0xFF718096),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF667EEA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Try Again Later'),
          ),
        ],
      ),
    );
  }

  // --- Classification Helper Functions ---

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

  // Auto-classification dialog
  Future<void> _showClassificationDialog(int systolic, int diastolic) async {
    if (!mounted) return;

    final category = _getBPCategory(systolic, diastolic);
    final color = _getBPColor(systolic, diastolic);

    final icon = category == 'Normal'
        ? Icons.check_circle_rounded
        : Icons.warning_rounded;

    String dynamicContent;
    String buttonText;

    if (category == 'Normal') {
      dynamicContent =
          'Great news! Your recorded Blood Pressure of $systolic/$diastolic mmHg is in the healthy range.';
      buttonText = 'Awesome!';
    } else if (category == 'Elevated') {
      dynamicContent =
          'Attention: Your recorded BP of $systolic/$diastolic mmHg is elevated. This is a warning sign. Focus on lifestyle adjustments now.';
      buttonText = 'Understood';
    } else if (category == 'High BP Stage 1') {
      dynamicContent =
          'Warning: Your recorded BP is in Stage 1 Hypertension ($systolic/$diastolic mmHg). Lifestyle changes and doctor consultation are strongly recommended.';
      buttonText = 'Acknowledge';
    } else if (category == 'High BP Stage 2') {
      dynamicContent =
          'Serious Warning: Your recorded BP is in Stage 2 Hypertension ($systolic/$diastolic mmHg). Please consult a healthcare professional immediately.';
      buttonText = 'Got it';
    } else if (category == 'Hypertensive Crisis') {
      dynamicContent =
          '🚨 URGENT: Your recorded BP is critical ($systolic/$diastolic mmHg)! Seek emergency medical attention right now.';
      buttonText = 'Got it';
    } else {
      dynamicContent =
          'Your recorded BP is $systolic/$diastolic mmHg. Check the Category Guide below for details.';
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
              child: Text(
                category,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
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

  // --- The Core Saving Function ---
  Future<void> _saveBPLog() async {
    // --- 1. INITIAL INPUT CHECK (Empty Fields) ---
    if (_systolicController.text.isEmpty || _diastolicController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both systolic and diastolic values'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // --- 2. PARSE & VALIDATE (Numerical Validity) ---
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);

    if (systolic == null || diastolic == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid numerical readings'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // --- 3. VALIDATE CLINICAL RANGES (Realism Check) ---
    const int minSystolic = 60;
    const int maxSystolic = 250;
    const int minDiastolic = 30;
    const int maxDiastolic = 150;

    if (systolic < minSystolic ||
        systolic > maxSystolic ||
        diastolic < minDiastolic ||
        diastolic > maxDiastolic ||
        diastolic >= systolic) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Readings out of range. Systolic must be 60-250 mmHg, Diastolic 30-150 mmHg, and Diastolic must be lower than Systolic.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
      }
      return;
    }

    // --- 4. CHECK INTERNET CONNECTION BEFORE SAVING ---
    final bool isConnected = await _hasInternetConnection();

    if (!isConnected) {
      // Show the no-internet dialog and stop here — do NOT save anything
      await _showNoInternetDialog();
      return;
    }

    // --- 5. SAVE DATA (Firestore and SharedPreferences) ---
    final prefs = await SharedPreferences.getInstance();
    final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

    final Map<String, dynamic> readingData = {
      'systolic': systolic,
      'diastolic': diastolic,
      'notes': _notesController.text,
      'date': DateTime.now().toIso8601String(),
      'type': 'BP_LOG',
    };

    try {
      await saveReadingToFirestore(type: 'BP_LOG', data: readingData);
    } catch (e) {
      // Catches any unexpected Firestore/network errors during the actual save call
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save reading. Please check your connection and try again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Save to local history
    if (loggedInUserEmail.isNotEmpty) {
      final history =
          prefs.getStringList('${loggedInUserEmail}_bpHistory') ?? [];
      history.insert(0, jsonEncode(readingData));
      await prefs.setStringList('${loggedInUserEmail}_bpHistory', history);
    }

    // 6. SHOW CLASSIFICATION ALERT
    await _showClassificationDialog(systolic, diastolic);

    // 7. FINAL SUCCESS & NAVIGATION
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood pressure recorded successfully'),
          backgroundColor: Color(0xFF48BB78),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Record Blood Pressure',
          style: TextStyle(color: Color(0xFF2D3748)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.edit_note, size: 60, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Record Your BP Reading',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _systolicController,
                decoration: const InputDecoration(
                  labelText: 'Systolic (Top Number)',
                  labelStyle: TextStyle(color: Color(0xFF718096)),
                  prefixIcon:
                      Icon(Icons.arrow_upward, color: Color(0xFF4FACFE)),
                  suffixText: 'mmHg',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _diastolicController,
                decoration: const InputDecoration(
                  labelText: 'Diastolic (Bottom Number)',
                  labelStyle: TextStyle(color: Color(0xFF718096)),
                  prefixIcon:
                      Icon(Icons.arrow_downward, color: Color(0xFF4FACFE)),
                  suffixText: 'mmHg',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  labelStyle: TextStyle(color: Color(0xFF718096)),
                  prefixIcon:
                      Icon(Icons.note_outlined, color: Color(0xFF4FACFE)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _saveBPLog,
              child: Container(
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
                  'Save Reading',
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
