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
import 'full_scan_result_screen.dart';

class FullScanMeasurementScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool cameraAlreadyReleased;

  const FullScanMeasurementScreen({
    super.key,
    required this.cameras,
    this.cameraAlreadyReleased = false,
  });

  @override
  State<FullScanMeasurementScreen> createState() =>
      _FullScanMeasurementScreenState();
}

class _FullScanMeasurementScreenState extends State<FullScanMeasurementScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isCollecting = false;
  int _timeElapsed = 0;
  Timer? _collectionTimer;
  final List<int> _rawGreenSignal = [];
  DateTime? _collectionStartTime;

  static const int _targetDurationSeconds = 20;
  static const double _targetFrameRate = 30;
  static const int _uiUpdateInterval = 10;

  // ── Finger-loss detection (RGB red-channel — matches FingerGuideScreen) ──
  //
  // Uses isLensCovered() exported from finger_guide_screen.dart.
  // Thresholds: red > 150, green < 100, red-green > 80.
  // No baseline needed — absolute check, not fooled by auto-exposure.
  //
  static const int _kWarmupFrames = 30; // ~1 s — let torch stabilise
  static const int _kBadFrameLimit = 20; // ~0.67 s consecutive bad → redirect

  int _warmupFrameCount = 0;
  int _consecutiveBadFrames = 0;
  // ─────────────────────────────────────────────────────────────────────────

  int _frameCounter = 0;
  int _displaySamples = 0;
  bool _isRedirecting = false;
  bool _analysisStarted = false;

  int? _userAge;
  int? _userGender;
  int? _userHeight;
  int? _userWeight;

  final String _sqiApiUrl = AppConfig.sqiApiUrl;
  final String _hrEstimationApiUrl = AppConfig.hrApiUrl;
  final String _bpEstimationApiUrl = AppConfig.bpApiUrl;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndInitCamera();
  }

  int? _parseToInt(String? value) {
    if (value == null || value.isEmpty) return null;
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue.round();
    return null;
  }

  Future<void> _loadUserDataAndInitCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInEmail = prefs.getString('loggedInUserEmail') ?? '';
    if (loggedInEmail.isEmpty) {
      _showErrorDialog('Not Logged In', 'Please log in to use full scan.');
      return;
    }

    final ageStr = prefs.getString('${loggedInEmail}_userAge');
    final heightStr = prefs.getString('${loggedInEmail}_userHeight');
    final weightStr = prefs.getString('${loggedInEmail}_userWeight');
    final genderStr = prefs.getString('${loggedInEmail}_userGender');

    _userAge = _parseToInt(ageStr);
    _userHeight = _parseToInt(heightStr);
    _userWeight = _parseToInt(weightStr);

    if (genderStr == 'Male') {
      _userGender = 1;
    } else if (genderStr == 'Female') {
      _userGender = 0;
    } else {
      _userGender = 1;
    }

    if (_userAge == null || _userHeight == null || _userWeight == null) {
      _showErrorDialog(
        'Incomplete Profile',
        'Age, height, and weight are required for full scan BP estimation. '
            'Please update your profile and try again.',
      );
      return;
    }

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    CameraDescription? backCamera;
    try {
      backCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
    } catch (_) {
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
      await _controller!.setFocusMode(FocusMode.locked);
      // Let auto-exposure adapt to the torch light BEFORE locking.
      // Locking immediately captures a dark "normal scene" exposure value.
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      try {
        final double minEV = await _controller!.getMinExposureOffset();
        final double maxEV = await _controller!.getMaxExposureOffset();
        // +1 EV makes the preview bright enough to see your finger.
        final double targetEV = 1.0.clamp(minEV, maxEV);
        await _controller!.setExposureOffset(targetEV);
      } catch (_) {
        // Exposure offset not supported on this device — safe to ignore.
      }
      await _controller!.setExposureMode(ExposureMode.locked);

      setState(() {});

      // 200 ms is enough — we already waited 800 ms for exposure above.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_isCollecting && !_isRedirecting) {
          _startCollection();
        }
      });
    } catch (e) {
      _showErrorDialog(
        'Camera Error',
        'Failed to initialize camera. Please try again.',
      );
    }
  }

  // ── Finger-loss check ─────────────────────────────────────────────────────

  /// Returns true when the finger has been removed long enough to redirect.
  bool _checkFingerLoss(CameraImage image) {
    // Skip warmup — torch may not be fully stable yet
    if (_warmupFrameCount < _kWarmupFrames) {
      _warmupFrameCount++;
      return false;
    }

    if (isLensCovered(image)) {
      _consecutiveBadFrames = 0; // good frame — reset counter
      return false;
    } else {
      _consecutiveBadFrames++;
      return _consecutiveBadFrames >= _kBadFrameLimit;
    }
  }

  // ── Green signal extractor (unchanged) ───────────────────────────────────

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
    int sum = 0;
    int count = 0;
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

  // ── Redirect (unchanged) ──────────────────────────────────────────────────

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
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finger removed. Please place finger again.'),
            backgroundColor: Color(0xFFF56565),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FingerGuideScreen(
              cameras: widget.cameras,
              cameraAlreadyReleased: true,
              measurementType: 'full',
            ),
          ),
        );
      }
    });
  }

  // ── Collection ────────────────────────────────────────────────────────────

  Future<void> _startCollection() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isCollecting = true;
      _isProcessing = false;
      _timeElapsed = 0;
      _frameCounter = 0;
      _displaySamples = 0;
      _isRedirecting = false;
      _analysisStarted = false;
      _rawGreenSignal.clear();
      // Reset finger-loss counters
      _warmupFrameCount = 0;
      _consecutiveBadFrames = 0;
      _collectionStartTime = DateTime.now();
    });

    try {
      await _controller!.startImageStream((CameraImage image) {
        if (!_isCollecting || _isRedirecting || _analysisStarted) return;

        _frameCounter++;

        // ── Finger-loss check (RGB) — runs before signal collection ──────
        if (_checkFingerLoss(image)) {
          _triggerReturnToFingerGuide();
          return; // don't add bad frames to the signal
        }

        // ── Signal collection (unchanged) ────────────────────────────────
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
    } catch (_) {
      _showErrorDialog('Stream Error', 'Failed to start image stream.');
      return;
    }

    _collectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isRedirecting) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeElapsed++;
        if (_timeElapsed >= _targetDurationSeconds) {
          timer.cancel();
          if (!_analysisStarted && !_isRedirecting) {
            _analysisStarted = true;
            _sendDataForAnalysis();
          }
        }
      });
    });
  }

  // ── Calibration (unchanged) ───────────────────────────────────────────────

  List<double> _applyCalibration({
    required double sbp0,
    required double dbp0,
    required int height,
    required int weight,
  }) {
    const List<List<double>> W = [
      [0.92, 0.05, 0.01, 0.02],
      [0.03, 0.88, 0.00, 0.01],
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

  // ── API (unchanged) ───────────────────────────────────────────────────────

  Future<void> _sendDataForAnalysis() async {
    if (mounted) {
      setState(() {
        _isCollecting = false;
        _isProcessing = true;
      });
    }

    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}
    }
    _collectionTimer?.cancel();

    if (_rawGreenSignal.length < _targetFrameRate * 15) {
      _showErrorDialog('Data Too Short',
          'Need at least 15 seconds of good data. Please try again.');
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog('Authentication Required', 'Please log in again.');
      return;
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null) {
      _showErrorDialog(
          'Authentication Error', 'Could not retrieve user token.');
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
    final List<double> ppgFloats =
        trimmed.take(fsToSend * 20).map((e) => e.toDouble()).toList();

    final Map<String, dynamic> requestBody = {
      'ppg_signal': ppgFloats,
      'fs': fsToSend,
    };

    try {
      final sqiResponse = await http
          .post(
            Uri.parse(_sqiApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (sqiResponse.statusCode != 200) {
        _showErrorDialog('PPG Signal Quality Check Error',
            'Fingertip PPG Signal Quality check failed. Please try again.');
        return;
      }

      final Map<String, dynamic> sqiResult = jsonDecode(sqiResponse.body);
      if (sqiResult['quality'] != 'GOOD') {
        _showErrorDialog(
          'Poor Signal Quality',
          '${sqiResult['reason']}\n\nTips:\n'
              '- Keep finger flat on camera\n'
              '- Stay still\n'
              '- Don\'t press too hard',
        );
        return;
      }

      final hrFuture = http
          .post(
            Uri.parse(_hrEstimationApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      final bpFuture = http
          .post(
            Uri.parse(_bpEstimationApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      final responses = await Future.wait([hrFuture, bpFuture]);
      final hrResponse = responses[0];
      final bpResponse = responses[1];

      if (hrResponse.statusCode != 200) {
        _showErrorDialog('HR Service Error',
            'HR API returned status code: ${hrResponse.statusCode}.');
        return;
      }
      if (bpResponse.statusCode != 200) {
        _showErrorDialog('BP Service Error',
            'BP API returned status code: ${bpResponse.statusCode}.');
        return;
      }

      final Map<String, dynamic> hrResult = jsonDecode(hrResponse.body);
      final Map<String, dynamic> bpResult = jsonDecode(bpResponse.body);

      final int hr = (hrResult['hr'] as num?)?.round() ?? 0;
      final double hrv = (hrResult['hrv'] as num?)?.toDouble() ?? 0.0;
      final double sbp0 = (bpResult['sbp0'] as num?)?.toDouble() ?? 0.0;
      final double dbp0 = (bpResult['dbp0'] as num?)?.toDouble() ?? 0.0;

      final calibrated = _applyCalibration(
        sbp0: sbp0,
        dbp0: dbp0,
        height: _userHeight!,
        weight: _userWeight!,
      );

      final int systolic = calibrated[0].round();
      final int diastolic = calibrated[1].round();

      final nowIso = DateTime.now().toIso8601String();
      final Map<String, dynamic> fullReading = {
        'hr': hr,
        'hrv': hrv,
        'systolic': systolic,
        'diastolic': diastolic,
        'date': nowIso,
        'type': 'FULL_SCAN',
      };
      final Map<String, dynamic> hrReading = {
        'hr': hr,
        'hrv': hrv,
        'date': nowIso,
        'type': 'HR/HRV',
      };
      final Map<String, dynamic> bpReading = {
        'systolic': systolic,
        'diastolic': diastolic,
        'date': nowIso,
        'type': 'BP',
      };

      await saveReadingToFirestore(type: 'FULL_SCAN', data: fullReading);
      await saveReadingToFirestore(type: 'HR/HRV', data: hrReading);
      await saveReadingToFirestore(type: 'BP', data: bpReading);

      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('loggedInUserEmail') ?? '';
      if (email.isNotEmpty) {
        final hrHistory = prefs.getStringList('${email}_hrHistory') ?? [];
        hrHistory.insert(0, jsonEncode(hrReading));
        await prefs.setStringList('${email}_hrHistory', hrHistory);

        final bpHistory = prefs.getStringList('${email}_bpHistory') ?? [];
        bpHistory.insert(0, jsonEncode(bpReading));
        await prefs.setStringList('${email}_bpHistory', bpHistory);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FullScanResultScreen(
              hr: hr,
              hrv: hrv,
              systolic: systolic,
              diastolic: diastolic,
              cameras: widget.cameras,
            ),
          ),
        );
      }
    } on TimeoutException {
      _showErrorDialog(
          'Connection Timeout', 'Server response timeout. Please try again.');
    } catch (e) {
      _showErrorDialog('Network Error', 'Failed to complete full scan: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Stop collection (unchanged) ───────────────────────────────────────────

  Future<void> _stopCollection() async {
    _collectionTimer?.cancel();
    _collectionTimer = null;
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.setFlashMode(FlashMode.off);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isCollecting = false;
        _isProcessing = false;
      });
    }
  }

  // ── Error dialog (unchanged) ──────────────────────────────────────────────

  void _showErrorDialog(String title, String content) {
    try {
      _controller?.setFlashMode(FlashMode.off);
    } catch (_) {}
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // ── Dispose (unchanged) ───────────────────────────────────────────────────

  @override
  void dispose() {
    _isRedirecting = true;
    _collectionTimer?.cancel();
    if (_controller != null) {
      final ctrl = _controller!;
      _controller = null;
      Future(() async {
        try {
          if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
          await ctrl.setFlashMode(FlashMode.off);
          await ctrl.dispose();
        } catch (_) {}
      });
    }
    super.dispose();
  }

  // ── Build (unchanged) ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(255, 250, 234, 57)),
              ),
              SizedBox(height: 16),
              Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_isProcessing && !_isCollecting) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(255, 250, 234, 57),
                    ),
                  ),
                ),
                SizedBox(height: 28),
                Text(
                  'Analyzing your signal...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'This may take up to 30 seconds.\nPlease keep the app open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
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
                          await _stopCollection();
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      const Text(
                        'Full Scan Measurement',
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
                          Color.fromARGB(255, 250, 234, 57),
                        ),
                      ),
                    ),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.45),
                        border: Border.all(
                          color: const Color.fromARGB(255, 250, 234, 57),
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
                              color: Color.fromARGB(255, 250, 234, 57),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCollecting
                                ? '$_displaySamples samples recorded | Target: 20 seconds'
                                : 'Starting...',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
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
