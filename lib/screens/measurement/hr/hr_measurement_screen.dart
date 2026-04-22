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
import '../hr/hr_result_screen.dart';

class HRMeasurementScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool cameraAlreadyReleased;

  const HRMeasurementScreen({
    super.key,
    required this.cameras,
    this.cameraAlreadyReleased = false,
  });

  @override
  _HRMeasurementScreenState createState() => _HRMeasurementScreenState();
}

class _HRMeasurementScreenState extends State<HRMeasurementScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isCollecting = false;
  int _timeElapsed = 0;
  Timer? _collectionTimer;
  bool _isStoppingManually = false;

  final List<int> _rawGreenSignal = [];
  static const double _targetFrameRate = 30;
  static const int _targetDurationSeconds = 20;
  DateTime? _collectionStartTime; // Used to compute actual sample rate
  static const int _kWarmupFrames = 30; // ~1 s — let torch stabilise
  static const int _kBadFrameLimit = 20; // ~0.67 s consecutive bad → redirect

  int _warmupFrameCount = 0;
  int _consecutiveBadFrames = 0;
  // ─────────────────────────────────────────────────────────────────────────

  // Guards — all written/read on main thread via addPostFrameCallback
  bool _isRedirecting = false;
  bool _analysisStarted = false;

  // Frame counter for throttling UI updates
  int _frameCounter = 0;
  static const int _uiUpdateInterval = 10; // Rebuild UI every 10 frames (~3fps)

  // Cached display values — updated every _uiUpdateInterval frames
  int _displaySamples = 0;

  final String _sqiApiUrl = AppConfig.sqiApiUrl;
  final String _hrEstimationApiUrl = AppConfig.hrApiUrl;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    await Future.delayed(const Duration(milliseconds: 300));

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
      // Wait for auto-exposure to adapt to torch light BEFORE locking.
      // Locking immediately captures a dark "normal scene" exposure value,
      // which is why the preview looks nearly black with a finger on it.
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      try {
        final double minEV = await _controller!.getMinExposureOffset();
        final double maxEV = await _controller!.getMaxExposureOffset();
        // +1 EV brightens the preview enough to clearly see finger placement.
        final double targetEV = 1.0.clamp(minEV, maxEV);
        await _controller!.setExposureOffset(targetEV);
      } catch (_) {
        // Exposure offset not supported on this device — safe to ignore.
      }
      await _controller!.setExposureMode(ExposureMode.locked);

      setState(() {});

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isCollecting && !_isRedirecting) {
          _startCollection();
        }
      });
    } catch (e) {
      print('HR camera init error: $e');
      if (mounted) {
        _showErrorDialog(
            'Camera Error', 'Failed to initialize camera. Please try again.');
      }
    }
  }

  // ── Finger-loss check (RGB red-channel) ───────────────────────────────────

  bool _checkFingerLoss(CameraImage image) {
    if (_warmupFrameCount < _kWarmupFrames) {
      _warmupFrameCount++;
      return false;
    }

    if (isLensCovered(image)) {
      _consecutiveBadFrames = 0;
      return false;
    } else {
      _consecutiveBadFrames++;
      return _consecutiveBadFrames >= _kBadFrameLimit;
    }
  }

  int _extractGreenValue(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) return 128;

    final int width = image.width;
    final int height = image.height;
    final List<int> yPlane = image.planes[0].bytes;
    final int stride = image.planes[0].bytesPerRow;

    // Sample every 4th pixel in both axes (stride=4) in the centre 50% region.
    // This gives ~(width/8) * (height/8) samples — accurate enough for PPG
    // while running ~16x faster than sampling every pixel.
    // Faster callback = less frame-drop = actual fps closer to 30 = correct fs.
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
          if (ctrl.value.isStreamingImages) {
            await ctrl.stopImageStream();
          }
          await ctrl.setFlashMode(FlashMode.off);
          await ctrl.dispose();
        } catch (e) {
          print('Error disposing HR camera before redirect: $e');
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
            ),
          ),
        );
      }
    });
  }

  Future<void> _startCollection() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isCollecting = true;
      _isProcessing = false;
      _timeElapsed = 0;
      _frameCounter = 0;
      _displaySamples = 0;
      _isRedirecting = false;
      _isStoppingManually = false;
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

        // ── Finger-loss check (RGB red-channel) — runs before signal collection
        if (_checkFingerLoss(image)) {
          print('[HR FingDet] Finger removal detected via RGB red-channel!');
          _triggerReturnToFingerGuide();
          return; // don't add bad frames to the signal
        }

        final int greenValue = _extractGreenValue(image);
        if (greenValue > 10) {
          _rawGreenSignal.add(greenValue);
        }

        // FIX 8: Throttle UI updates — only rebuild every _uiUpdateInterval frames
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
    } catch (e) {
      print('Stream start error: $e');
      if (mounted) {
        setState(() => _isCollecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopCollection() async {
    _collectionTimer?.cancel();
    _collectionTimer = null;

    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.setFlashMode(FlashMode.off);
      } catch (e) {
        print('Stop collection error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isCollecting = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _sendDataForAnalysis() async {
    if (mounted) {
      setState(() {
        _isCollecting = false;
        _isProcessing = true;
      });
    }

    // Stop camera before network calls
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.setFlashMode(FlashMode.off);
      } catch (e) {
        print('Stream stop before analysis error: $e');
      }
    }

    _collectionTimer?.cancel();

    if (_rawGreenSignal.length < _targetFrameRate * 15) {
      _showErrorDialog(
        'Not Enough Data',
        'Only $_displaySamples samples collected. '
            'Keep your finger firmly on the camera for the full 20 seconds.',
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog('Login Required', 'Please log in to save measurements.');
      return;
    }
    final String? idToken = await user.getIdToken();
    if (idToken == null) {
      _showErrorDialog(
          'Auth Error', 'Could not get auth token. Please re-login.');
      return;
    }

    // Compute the ACTUAL sample rate from real elapsed time.
    // The camera does not always deliver exactly 30fps — heavy pixel processing,
    // background tasks, and OS scheduling all reduce the real rate.
    // Sending the wrong fs to the server is the primary cause of 500 errors
    // because the server's FFT-based HR algorithm is frequency-dependent.
    final double actualElapsedSeconds = _collectionStartTime != null
        ? DateTime.now().difference(_collectionStartTime!).inMilliseconds /
            1000.0
        : _targetDurationSeconds.toDouble();
    final double actualFs = _rawGreenSignal.length / actualElapsedSeconds;
    // Clamp to a sane range — never send a clearly wrong value to the server
    final int fsToSend = actualFs.clamp(10.0, 35.0).round();

    // Trim the first ~1s of samples (flash warm-up transient distorts the signal)
    final int trimCount = fsToSend; // 1 second worth
    final List<int> trimmed = _rawGreenSignal.length > trimCount
        ? _rawGreenSignal.sublist(trimCount)
        : _rawGreenSignal;

    // Cap at 35 * 20 = 700 samples to avoid oversized payloads
    final List<double> ppgFloats =
        trimmed.take(fsToSend * 20).map((e) => e.toDouble()).toList();

    print(
        '[HR] samples=${_rawGreenSignal.length} elapsed=${actualElapsedSeconds.toStringAsFixed(1)}s actualFs=${actualFs.toStringAsFixed(1)} sending fs=$fsToSend count=${ppgFloats.length}');

    final Map<String, dynamic> requestBody = {
      'ppg_signal': ppgFloats,
      'fs': fsToSend, // Integer — some servers reject 30.0 as a float
    };

    try {
      // Step 1: SQI
      final sqiResponse = await http
          .post(
            Uri.parse(_sqiApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      // Log full server response for debugging 500 errors
      print(
          '[SQI] status=${sqiResponse.statusCode} body=${sqiResponse.body.substring(0, sqiResponse.body.length.clamp(0, 300))}');

      if (sqiResponse.statusCode != 200) {
        String detail = '';
        try {
          final Map<String, dynamic> errJson = json.decode(sqiResponse.body);
          detail =
              errJson['detail'] ?? errJson['error'] ?? errJson['message'] ?? '';
        } catch (_) {
          detail = sqiResponse.body
              .substring(0, sqiResponse.body.length.clamp(0, 150));
        }
        _showErrorDialog(
          'Server Error (${sqiResponse.statusCode})',
          detail.isNotEmpty
              ? detail
              : 'Fingertip PPG Signal Quality check failed. Please try again.',
        );
        return;
      }

      final Map<String, dynamic> sqiResult = json.decode(sqiResponse.body);
      if (sqiResult['quality'] != 'GOOD') {
        _showErrorDialog(
          'Poor Signal Quality',
          '${sqiResult['reason']}.\n\nTips: keep finger flat and still, avoid pressing too hard.',
        );
        return;
      }

      // Step 2: HR/HRV
      final hrResponse = await http
          .post(
            Uri.parse(_hrEstimationApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (hrResponse.statusCode == 200) {
        final Map<String, dynamic> hrResult = json.decode(hrResponse.body);
        final int hr = (hrResult['hr'] as num?)?.round() ?? 0;
        final double hrv = (hrResult['hrv'] as num?)?.toDouble() ?? 0.0;

        final prefs = await SharedPreferences.getInstance();
        final String email = prefs.getString('loggedInUserEmail') ?? '';

        final Map<String, dynamic> readingData = {
          'hr': hr,
          'hrv': hrv,
          'date': DateTime.now().toIso8601String(),
          'type': 'HR/HRV',
        };

        await saveReadingToFirestore(type: 'HR/HRV', data: readingData);

        if (email.isNotEmpty) {
          final history = prefs.getStringList('${email}_hrHistory') ?? [];
          history.insert(0, jsonEncode(readingData));
          await prefs.setStringList('${email}_hrHistory', history);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HRResultScreen(hr: hr, hrv: hrv),
            ),
          );
        }
      } else if (hrResponse.statusCode == 401) {
        _showErrorDialog('Session Expired', 'Please log out and log back in.');
      } else {
        // Log the full error body so we can diagnose 500s
        print(
            '[HR] error body: ${hrResponse.body.substring(0, hrResponse.body.length.clamp(0, 300))}');
        String detail = '';
        try {
          final Map<String, dynamic> errJson = json.decode(hrResponse.body);
          detail =
              errJson['detail'] ?? errJson['error'] ?? errJson['message'] ?? '';
        } catch (_) {
          detail = hrResponse.body
              .substring(0, hrResponse.body.length.clamp(0, 150));
        }
        _showErrorDialog(
          'Server Error (${hrResponse.statusCode})',
          detail.isNotEmpty
              ? detail
              : 'HR estimation failed. Please try again.',
        );
      }
    } on TimeoutException {
      _showErrorDialog(
        'Connection Timeout',
        'Server is slow to respond. It may be waking up. '
            'Please wait a moment and try again.',
      );
    } catch (e) {
      _showErrorDialog('Network Error', 'Could not reach the server: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

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
        } catch (e) {
          print('HR dispose error: $e');
        }
      });
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Camera loading
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)),
              ),
              SizedBox(height: 16),
              Text('Starting camera...',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Processing — server call in progress
    if (_isProcessing && !_isCollecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Analyzing your signal...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This may take up to 30 seconds.\nPlease keep the app open.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Measurement screen
    // Progress ring: fills up from 0 → 1 as time progresses
    final int _timeRemaining = _targetDurationSeconds - _timeElapsed;
    final double progress = _timeElapsed / _targetDurationSeconds;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera
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
                // Top bar
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
                        'Heart Rate & HRV Measurement',
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

                // Progress ring + timer
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
                            Color(0xFF48BB78)),
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
                              ? const Color(0xFF48BB78)
                              : const Color(0xFFFF6B9D),
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isCollecting
                                ? '$_timeRemaining'
                                : '$_targetDurationSeconds',
                            style: const TextStyle(
                              fontSize: 58,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _isCollecting
                                ? (_timeRemaining == 1
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

                // Bottom status panel — no button, fully automatic
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
                              color: Color(0xFF48BB78),
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
