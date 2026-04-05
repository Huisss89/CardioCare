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

  // ── Finger removal detection ────────────────────────────────────────────
  // Strategy: learn the baseline brightness during the first ~1s (warmup),
  // then flag a frame as "bad" if its brightness drops more than 40% below
  // that baseline. This is lighting-environment-independent — it doesn't
  // matter whether the room is bright or dark, what matters is the DROP
  // relative to what the camera saw with the finger confirmed on.
  //
  // A heartbeat pulse typically shifts brightness by ~5–15%. Removing the
  // finger drops brightness by 40–80% (flash no longer passes through tissue).
  // So a 40% drop threshold sits safely between the two.
  //
  // Uses a sliding window so brief micro-lifts (1–3 frames) don't trigger
  // a redirect. Needs >70% of the last 45 frames to be "bad" to redirect.
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

  double _baselineBrightness = 0; // mean brightness measured during warmup
  int _warmupSum = 0; // accumulator for baseline calculation
  int _warmupCount = 0;
  final List<bool> _fingerWindow = [];

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

    // FIX 1: FingerGuideScreen already disposed its controller before
    // navigating here — only a short settle delay is needed now.
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
      await _controller!.setExposureMode(ExposureMode.locked);
      await _controller!.setFocusMode(FocusMode.locked);

      setState(() {});

      // FIX 2: Start collection faster — 600ms instead of 1500ms
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

  // Returns the mean brightness of the central 80×80 pixel region (Y-plane).
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

  // Returns true if brightness indicates the finger is still present.
  // Compares against the personal baseline learned during warmup — this makes
  // detection independent of room lighting or device flash brightness.
  // A real finger-off event drops brightness by 40–80%; a heartbeat pulse
  // only shifts it by 5–15%, so a 40% drop threshold reliably separates them.
  bool _isFingerStillPresent(double brightness) {
    if (brightness < 0) return true; // unknown format — don't penalise
    if (_baselineBrightness <= 0) return true; // baseline not ready yet
    return brightness >= _baselineBrightness * (1.0 - _dropRatio);
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

  // FIX 4: Trigger is synchronous (sets flag immediately to drop frames),
  // but actual camera disposal + navigation runs on main thread via callback.
  void _triggerReturnToFingerGuide() {
    if (_isRedirecting) return;
    _isRedirecting = true;

    _collectionTimer?.cancel();
    _collectionTimer = null;

    // KEY FIX: Grab controller ref and null it via setState immediately.
    // This forces a rebuild to the loading screen before any async disposal,
    // preventing "buildPreview() was called on a disposed CameraController".
    final CameraController? ctrl = _controller;
    if (mounted) {
      setState(() {
        _controller = null; // UI rebuilds → loading screen, CameraPreview stops
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

        // FIX 6: Pass cameraAlreadyReleased=true so FingerGuideScreen
        // knows we properly disposed and uses a shorter settle delay
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
      _fingerWindow.clear();
      _baselineBrightness = 0;
      _warmupSum = 0;
      _warmupCount = 0;
      _consecutiveBadFrames = 0; // ADD THIS LINE
      _collectionStartTime = DateTime.now();
    });

    try {
      await _controller!.startImageStream((CameraImage image) {
        if (!_isCollecting || _isRedirecting || _analysisStarted) return;

        _frameCounter++;

        // ── Baseline learning (warmup phase) ────────────────────────────
        // During the first _warmupFrames frames the finger is confirmed on
        // (FingerGuideScreen verified it before navigating here). Accumulate
        // brightness to build a personal baseline for THIS user's finger and
        // THIS device's flash intensity.
        final double brightness = _getMeanBrightness(image);

        if (_frameCounter <= _warmupFrames) {
          if (brightness > 0) {
            _warmupSum += brightness.round();
            _warmupCount += 1;
            // Finalise baseline on the last warmup frame
            if (_frameCounter == _warmupFrames && _warmupCount > 0) {
              _baselineBrightness = _warmupSum / _warmupCount;
              print(
                  '[FingDet] baseline=${_baselineBrightness.toStringAsFixed(1)}');
            }
          }
        } else {
          // ── Detection phase (dual-check: immediate + sliding window) ────
          final bool fingerPresent = _isFingerStillPresent(brightness);

          // IMMEDIATE CHECK: Count consecutive bad frames
          if (!fingerPresent) {
            _consecutiveBadFrames++;
            // If 15 consecutive bad frames (~0.5s), redirect immediately
            if (_consecutiveBadFrames >= _immediateRedirectThreshold) {
              print('[BP FingDet] Immediate removal detected!');
              _triggerReturnToFingerGuide();
              return;
            }
          } else {
            // Reset counter when finger is detected again
            _consecutiveBadFrames = 0;
          }

          // SLIDING WINDOW CHECK: Overall trend over 1 second
          _fingerWindow.add(fingerPresent);
          if (_fingerWindow.length > _windowSize) {
            _fingerWindow.removeAt(0);
          }
          if (_fingerWindow.length >= _windowSize) {
            final int badCount = _fingerWindow.where((v) => !v).length;
            if (badCount > _badFrameLimit) {
              print('[BP FingDet] Sustained removal detected via window!');
              _triggerReturnToFingerGuide();
              return;
            }
          }
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
              : 'PPG SQI check failed. Please try again.',
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
                const SizedBox(height: 24),
                Text(
                  '$_displaySamples samples collected.',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
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
