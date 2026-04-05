import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../../../finger_guide_screen.dart';
import '../../../../utils/firestore_utils.dart';
import '../../../config/app_config.dart';
import '../bp/bp_result_screen.dart';

class BPMeasurementScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool cameraAlreadyReleased;
  const BPMeasurementScreen({
    super.key,
    required this.cameras,
    this.cameraAlreadyReleased = false,
  });
  @override
  _BPMeasurementScreenState createState() => _BPMeasurementScreenState();
}

class _BPMeasurementScreenState extends State<BPMeasurementScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isCollecting = false;
  int _timeElapsed = 0;
  Timer? _collectionTimer;
  bool _isStoppingManually = false;

  final List<int> _rawGreenSignal = [];
  static const double _targetFrameRate = 30.0;
  static const int _targetDurationSeconds = 20;
  DateTime? _collectionStartTime;

  // ── Finger removal detection (same adaptive baseline as HRMeasurementScreen)
// NEW VALUES (more sensitive detection):
  static const int _warmupFrames = 30; // Keep same - 1s warmup
  static const int _windowSize = 30; // Reduced from 45 to 30 (1 second window)
  static const int _badFrameLimit =
      20; // Reduced from 32 to 20 (67% bad = redirect)
  static const double _dropRatio =
      0.35; // Reduced from 0.40 to 0.35 (more sensitive)
  int _consecutiveBadFrames = 0;
  static const int _immediateRedirectThreshold =
      15; // 15 consecutive bad frames (~0.5s)
  int _cameraInitAttempts = 0;
  static const int _maxCameraInitAttempts = 3;

  double _baselineBrightness = 0;
  int _warmupSum = 0;
  int _warmupCount = 0;
  final List<bool> _fingerWindow = [];
  bool _isRedirecting = false;
  int _frameCounter = 0;
  static const int _uiUpdateInterval = 10;
  int _displaySamples = 0;

  // --- NEW: Separate API URLs ---
  // Use the new SQI API URL
  final String _sqiApiUrl = AppConfig.sqiApiUrl;
  final String _bpEstimationApiUrl = AppConfig.bpApiUrl;

  // User Demographics
  int? _userAge;
  int? _userGender;
  int? _userHeight;
  int? _userWeight;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndInitCamera();
  }

  // Finger detection helpers — identical logic to HRMeasurementScreen
  double _getMeanBrightness(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) return -1;
    final int width = image.width;
    final int height = image.height;
    final List<int> yPlane = image.planes[0].bytes;
    final int yStride = image.planes[0].bytesPerRow;
    final int cx = width ~/ 2;
    final int cy = height ~/ 2;
    const int range = 40;
    int sum = 0, count = 0;
    for (int y = cy - range; y < cy + range; y += 2) {
      for (int x = cx - range; x < cx + range; x += 2) {
        if (y >= 0 && y < height && x >= 0 && x < width) {
          final int idx = y * yStride + x;
          if (idx < yPlane.length) {
            sum += yPlane[idx];
            count++;
          }
        }
      }
    }
    return count > 0 ? sum / count : -1;
  }

  bool _isFingerStillPresent(double brightness) {
    if (brightness < 0) return true;
    if (_baselineBrightness <= 0) return true;
    return brightness >= _baselineBrightness * (1.0 - _dropRatio);
  }

  void _triggerReturnToFingerGuide() {
    if (_isRedirecting) return;
    _isRedirecting = true;

    _collectionTimer?.cancel();
    _collectionTimer = null;

    final CameraController? ctrl = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        _isCollecting = false;
        _isProcessing = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (ctrl != null) {
        try {
          if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
          await ctrl.setFlashMode(FlashMode.off);
          await ctrl.dispose();
        } catch (e) {
          print('BP camera dispose on redirect: $e');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finger removed. Please place finger again.'),
            backgroundColor: Color(0xFFF56565),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FingerGuideScreen(
              cameras: widget.cameras,
              cameraAlreadyReleased: true,
              measurementType: 'bp',
            ),
          ),
        );
      }
    });
  }

  List<double> _applyCalibration({
    required double sbp0,
    required double dbp0,
    required int height,
    required int weight,
  }) {
    /// Example Ridge calibration weights
    /// Replace with YOUR trained values later
    const List<List<double>> W = [
      [0.92, 0.05, 0.01, 0.02], // SBP row
      [0.03, 0.88, 0.00, 0.01], // DBP row
    ];

    const List<double> b = [3.5, 2.0];

    final x = [sbp0, dbp0, height.toDouble(), weight.toDouble()];

    double sbp = b[0];
    double dbp = b[1];

    for (int i = 0; i < x.length; i++) {
      sbp += W[0][i] * x[i];
      dbp += W[1][i] * x[i];
    }

    return [sbp, dbp];
  }

  // Helper to parse string to int, handling decimal values
  int? _parseToInt(String? value) {
    if (value == null || value.isEmpty) return null;

    // Try parsing as int first
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    // If that fails, try parsing as double and convert to int
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue.round();

    return null;
  }

  Future<void> _loadUserDataAndInitCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInEmail = prefs.getString('loggedInUserEmail') ?? '';

    print('[BP] Loading profile for user: $loggedInEmail');

    if (loggedInEmail.isEmpty) {
      _showErrorDialog('Not Logged In', 'Please log in to use BP estimation.');
      return;
    }

    // Debug: Show ALL user-related keys
    print('[BP] Checking stored data...');
    for (var key in prefs.getKeys()) {
      if (key.contains(loggedInEmail)) {
        print('[BP]   $key = ${prefs.get(key)}');
      }
    }

    // Load demographic data WITH email prefix
    final ageStr = prefs.getString('${loggedInEmail}_userAge');
    final heightStr = prefs.getString('${loggedInEmail}_userHeight');
    final weightStr = prefs.getString('${loggedInEmail}_userWeight');
    final genderStr = prefs.getString('${loggedInEmail}_userGender');

    print(
        '[BP] Raw values: age="$ageStr", height="$heightStr", weight="$weightStr", gender="$genderStr"');

// Parse values - handle both integer and decimal strings
    _userAge = _parseToInt(ageStr);
    _userHeight = _parseToInt(heightStr);
    _userWeight = _parseToInt(weightStr);

    print(
        '[BP] Parsed values: age=$_userAge, height=$_userHeight, weight=$_userWeight');

    // Handle gender
    if (genderStr == 'Male') {
      _userGender = 1;
    } else if (genderStr == 'Female') {
      _userGender = 0;
    } else {
      _userGender = null;
    }

    // Validate that all required fields are present
    if (_userAge == null || _userHeight == null || _userWeight == null) {
      print('[BP] ERROR - Missing or invalid profile data!');

      List<String> missingFields = [];
      if (_userAge == null) missingFields.add('Age (value: "$ageStr")');
      if (_userHeight == null)
        missingFields.add('Height (value: "$heightStr")');
      if (_userWeight == null)
        missingFields.add('Weight (value: "$weightStr")');

      _showErrorDialog('Incomplete Profile',
          'Missing or invalid data:\n\n${missingFields.join('\n')}\n\nPlease update your profile in the Profile tab.\n\nIf this persists, try logging out and back in.');
      return;
    }

    print('[BP] ✓ All data loaded successfully');
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    CameraDescription? backCamera;
    try {
      backCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
    } catch (e) {
      backCamera = null;
    }

    if (backCamera == null) {
      _showErrorDialog('Camera Error', 'Back camera not found.');
      return;
    }

    await Future.delayed(
      Duration(milliseconds: widget.cameraAlreadyReleased ? 400 : 200),
    );

    if (!mounted) return;

    _controller = CameraController(
      backCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();

      if (!mounted) {
        await _controller!.dispose();
        return;
      }

      await _controller!.setFlashMode(FlashMode.torch);
      await _controller!.setExposureMode(ExposureMode.locked);
      await _controller!.setFocusMode(FocusMode.locked);

      if (mounted) {
        setState(() {});
        _cameraInitAttempts = 0; // Reset on success
      }

      // Auto-start collection
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isCollecting && !_isRedirecting) {
          _startCollection();
        }
      });
    } on CameraException catch (e) {
      print('[BP] Camera init error (attempt ${_cameraInitAttempts + 1}): $e');

      _cameraInitAttempts++;

      if (_cameraInitAttempts < _maxCameraInitAttempts) {
        // Retry after a delay
        print('[BP] Retrying camera initialization...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _initializeCamera();
        }
      } else {
        // Max attempts reached
        _showErrorDialog('Camera Initialization Failed',
            'Could not access the camera after $_maxCameraInitAttempts attempts.\n\n${e.description ?? 'Please restart the app and try again.'}');
      }
    }
  }

  // Fast strided sampler — every 4th pixel, ~16x faster, keeps fps near 30.
  int _extractGreenValue(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) return 128;
    final int width = image.width;
    final int height = image.height;
    final List<int> yPlane = image.planes[0].bytes;
    final int stride = image.planes[0].bytesPerRow;
    final int xStart = width ~/ 4;
    final int xEnd = (width * 3) ~/ 4;
    final int yStart = height ~/ 4;
    final int yEnd = (height * 3) ~/ 4;
    const int step = 4;
    int sum = 0, count = 0;
    for (int y = yStart; y < yEnd; y += step) {
      for (int x = xStart; x < xEnd; x += step) {
        final int idx = y * stride + x;
        if (idx < yPlane.length) {
          sum += yPlane[idx];
          count++;
        }
      }
    }
    return count > 0 ? (sum / count).round() : 128;
  }

  Future<void> _startCollection() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_userAge == null) return;

    setState(() {
      _isCollecting = true;
      _isProcessing = false;
      _timeElapsed = 0;
      _frameCounter = 0;
      _displaySamples = 0;
      _isRedirecting = false;
      _isStoppingManually = false;
      _rawGreenSignal.clear();
      _fingerWindow.clear();
      _baselineBrightness = 0;
      _warmupSum = 0;
      _warmupCount = 0;
      _consecutiveBadFrames = 0; // ADD THIS LINE
      _collectionStartTime = DateTime.now();
    });

    try {
      await _controller!.startImageStream((CameraImage image) {
        if (!_isCollecting || _isRedirecting) return;

        _frameCounter++;

        // Adaptive baseline + sliding window finger detection
        final double brightness = _getMeanBrightness(image);

        if (_frameCounter <= _warmupFrames) {
          if (brightness > 0) {
            _warmupSum += brightness.round();
            _warmupCount += 1;
            if (_frameCounter == _warmupFrames && _warmupCount > 0) {
              _baselineBrightness = _warmupSum / _warmupCount;
              print(
                  '[BP FingDet] baseline=${_baselineBrightness.toStringAsFixed(1)}');
            }
          }
        } else {
          final bool fingerPresent = _isFingerStillPresent(brightness);
          _fingerWindow.add(fingerPresent);
          if (_fingerWindow.length > _windowSize) _fingerWindow.removeAt(0);
          if (_fingerWindow.length >= _windowSize) {
            final int badCount = _fingerWindow.where((v) => !v).length;
            if (badCount > _badFrameLimit) {
              _triggerReturnToFingerGuide();
              return;
            }
          }
        }

        final int greenValue = _extractGreenValue(image);
        if (greenValue > 10) _rawGreenSignal.add(greenValue);

        if (_frameCounter % _uiUpdateInterval == 0) {
          final int samples = _rawGreenSignal.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isRedirecting) {
              setState(() {
                _displaySamples = samples;
              });
            }
          });
        }
      });
    } on CameraException catch (e) {
      _showErrorDialog(
          'Stream Error', e.description ?? 'Failed to start stream.');
      return;
    }

    // Countdown: _timeElapsed counts up, UI shows remaining
    _collectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isRedirecting) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeElapsed++;
        if (_timeElapsed >= _targetDurationSeconds) {
          timer.cancel();
          if (!_isStoppingManually && !_isRedirecting) {
            _sendDataForAnalysis();
          }
        }
      });
    });
  }

  void _stopCollection() {
    _collectionTimer?.cancel();
    _controller?.stopImageStream();
    _controller?.setFlashMode(FlashMode.off);
    if (mounted) {
      setState(() {
        _isCollecting = false;
        _isProcessing = false;
        _isStoppingManually = true;
      });
    }
  }

// --- API Communication (UPDATED FOR TWO-STEP CALL) ---
  Future<void> _sendDataForAnalysis() async {
    if (mounted)
      setState(() {
        _isCollecting = false;
        _isProcessing = true;
      });

    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages)
          await _controller!.stopImageStream();
        await _controller!.setFlashMode(FlashMode.off);
      } catch (e) {
        print('BP stream stop: $e');
      }
    }
    _collectionTimer?.cancel();

    if (_rawGreenSignal.length < _targetFrameRate * 15) {
      _showErrorDialog('Data Too Short',
          'Need at least 15 seconds of good data for BP estimation.');
      return;
    }

    // --- 1. AUTHENTICATION & TOKEN FETCH ---
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog(
          "Authentication Required", "Please log in to perform measurements.");
      return;
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null) {
      _showErrorDialog(
          "Authentication Error", "Could not retrieve user token.");
      return;
    }

    // Check user demographic data (ensure required fields are present)
    if (_userAge == null || _userHeight == null || _userWeight == null) {
      _showErrorDialog(
          'Missing Data', 'Demographic data missing. Cannot estimate BP.');
      return;
    }

    final double actualElapsedSeconds = _collectionStartTime != null
        ? DateTime.now().difference(_collectionStartTime!).inMilliseconds /
            1000.0
        : _targetDurationSeconds.toDouble();
    final double actualFs = _rawGreenSignal.length / actualElapsedSeconds;
    final int fsToSend = actualFs.clamp(10.0, 35.0).round();

    final int trimCount = fsToSend;
    final List<int> trimmed = _rawGreenSignal.length > trimCount
        ? _rawGreenSignal.sublist(trimCount)
        : _rawGreenSignal;
    List<double> ppgFloats =
        trimmed.take(fsToSend * 20).map((e) => e.toDouble()).toList();

    print(
        '[BP] samples=${_rawGreenSignal.length} fs=$fsToSend count=${ppgFloats.length}');

    final Map<String, dynamic> baseRequestBody = {
      'ppg_signal': ppgFloats,
      'fs': fsToSend,
    };

    final Map<String, dynamic> demographicData = {
      'age': _userAge!,
      'gender': _userGender!,
      'height': _userHeight!,
      'weight': _userWeight!,
    };

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      // 2. STEP 1: SIGNAL QUALITY CHECK (SQI)
      final sqiResponse = await http
          .post(
            Uri.parse(_sqiApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(baseRequestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (sqiResponse.statusCode != 200) {
        // Handle SQI service error (e.g., internal server error, not SQI failure)
        _showErrorDialog('SQI Service Error',
            'API returned status code: ${sqiResponse.statusCode}. Check SQI server logs.');
        return;
      }

      final Map<String, dynamic> sqiResult = json.decode(sqiResponse.body);

      // Check if SQI quality is GOOD
      if (sqiResult['quality'] != 'GOOD') {
        print('[BP] SQI check failed: ${sqiResult['reason']}');

        // Stop and clean up camera FIRST
        final CameraController? ctrl = _controller;
        if (mounted) {
          setState(() {
            _controller = null; // Null it immediately
            _isProcessing = false;
            _isCollecting = false;
          });
        }

        // Dispose camera on next frame
        if (ctrl != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
              await ctrl.setFlashMode(FlashMode.off);
              await ctrl.dispose();
            } catch (e) {
              print('[BP] Error disposing camera after SQI failure: $e');
            }
          });
        }

        // Show dialog, then navigate back
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.warning_rounded, color: Color(0xFFF56565)),
                  SizedBox(width: 8),
                  Text('Poor PPG Signal Quality'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Try Again',
                      style: TextStyle(
                          color: Color(0xFF667EEA),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );

          // Navigate back to FingerGuideScreen with proper camera release flag
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FingerGuideScreen(
                  cameras: widget.cameras,
                  cameraAlreadyReleased: true,
                  measurementType: 'bp',
                ),
              ),
            );
          }
        }
        return;
      }

      // STEP 2: BASELINE BP ESTIMATION (PPG-only)
      final bpResponse = await http
          .post(
            Uri.parse(_bpEstimationApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization':
                  'Bearer $idToken', // remove if your BP server has no auth
            },
            body: jsonEncode({
              'ppg_signal': ppgFloats,
              'fs': fsToSend,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (bpResponse.statusCode == 200) {
        final Map<String, dynamic> bpResult = json.decode(bpResponse.body);

        // --- BASELINE BP FROM SERVER ---
        final double sbp0 = (bpResult['sbp0'] as num).toDouble();
        final double dbp0 = (bpResult['dbp0'] as num).toDouble();

        // --- LOCAL PERSONAL CALIBRATION ---
        final calibrated = _applyCalibration(
          sbp0: sbp0,
          dbp0: dbp0,
          height: _userHeight!,
          weight: _userWeight!,
        );

        final int systolic = calibrated[0].round();
        final int diastolic = calibrated[1].round();

        // --- SAVE RESULT ---
        final Map<String, dynamic> readingData = {
          'systolic': systolic,
          'diastolic': diastolic,
          'date': DateTime.now().toIso8601String(),
          'type': 'BP',
        };

        await saveReadingToFirestore(type: 'BP', data: readingData);

        final prefs = await SharedPreferences.getInstance();
        final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';
        final history =
            prefs.getStringList('${loggedInUserEmail}_bpHistory') ?? [];

        history.insert(0, jsonEncode(readingData));
        await prefs.setStringList('${loggedInUserEmail}_bpHistory', history);

        // --- NAVIGATE TO RESULT ---
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BPResultScreen(
              systolic: systolic,
              diastolic: diastolic,
              cameras: widget.cameras,
            ),
          ),
        );
      } else if (bpResponse.statusCode == 401) {
        _showErrorDialog(
            'Unauthorized', 'Your login token has expired. Please re-login.');
      } else {
        _showErrorDialog('BP Service Error',
            'API returned status code: ${bpResponse.statusCode}. Check Render logs.');
      }
    } on TimeoutException {
      _showErrorDialog('Connection Timeout',
          'The server took too long to respond. Please check connection or server status.');
    } catch (e) {
      _showErrorDialog('Network Error', 'Failed to connect: $e');
    } finally {
      // This ensures that if the try/catch fails, the UI returns from processing state.
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  //  _showErrorDialog and dispose methods here
  void _showErrorDialog(String title, String content) {
    _controller?.setFlashMode(FlashMode.off);
    //_controller?.dispose();
    _controller = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        Navigator.of(context).popUntil(
            (route) => route.isFirst || route.settings.name == '/home');
      }
    });
  }

  @override
  void dispose() {
    _collectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // Build Method
  @override
  Widget build(BuildContext context) {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _userAge == null) {
      // Show loading or error if profile data/camera isn't ready
      return Scaffold(
        body: Center(
            child: _userAge == null
                ? const Text('Loading User Data...')
                : const CircularProgressIndicator()),
      );
    }
    if (_isProcessing && !_isCollecting) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4FACFE)),
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Analyzing your signal...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This may take up to 30 seconds.\nPlease keep the app open.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    final int timeRemaining = _targetDurationSeconds - _timeElapsed;
    final double progress = _timeElapsed / _targetDurationSeconds;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () async {
                          _stopCollection();
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      const Text(
                        'Blood Pressure Measurement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      height: 210,
                      child: CircularProgressIndicator(
                        value: _isCollecting ? progress : 0,
                        strokeWidth: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 79, 196, 254)),
                      ),
                    ),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.45),
                        border: Border.all(
                          color: _isCollecting
                              ? const Color.fromARGB(255, 117, 217, 244)
                              : const Color(0xFF667EEA),
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isCollecting
                                ? '$timeRemaining'
                                : '$_targetDurationSeconds',
                            style: const TextStyle(
                              fontSize: 58,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _isCollecting
                                ? (timeRemaining == 1
                                    ? 'second left'
                                    : 'seconds left')
                                : 'seconds',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.92),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Keep your fingertip firmly on the camera',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4FACFE),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCollecting
                                ? '$_displaySamples samples recorded | Target: 20 seconds'
                                : 'Starting...',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
