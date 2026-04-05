import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/camera_utils.dart'; // Import extension for firstWhereOrNull
import 'screens/measurement/bp/bp_measurement_screen.dart';
import 'screens/measurement/hr/hr_measurement_screen.dart';
import 'screens/measurement/full_scan/full_scan_measurement_screen.dart';

class FingerGuideScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool cameraAlreadyReleased;

  /// 'hr' navigates to HRMeasurementScreen (default)
  /// 'bp' navigates to BPMeasurementScreen
  /// 'full' navigates to FullScanMeasurementScreen
  final String measurementType;

  const FingerGuideScreen({
    super.key,
    required this.cameras,
    this.cameraAlreadyReleased = false,
    this.measurementType = 'hr',
  });

  @override
  _FingerGuideScreenState createState() => _FingerGuideScreenState();
}

class _FingerGuideScreenState extends State<FingerGuideScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;

  bool _isFingerDetected = false;
  bool _isStable = false;
  int _currentBrightness = 0;
  double _currentStdDev = 0;

  int _stabilityCounter = 0;
  int _greenStateCounter = 0;
  int _frameCounter = 0;

  static const int _uiUpdateInterval = 6;
  static const int _autoStartDelay = 9;
  static const int _stabilityRequired = 8;

  bool _isNavigating = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPlacementGuideDialog();
    });
  }

  Future<void> _initializeCamera() async {
    final CameraDescription? backCamera = widget.cameras.firstWhereOrNull(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (backCamera == null) {
      _showErrorDialog('Camera Error', 'Back camera not found.');
      return;
    }

    await Future.delayed(
      Duration(milliseconds: widget.cameraAlreadyReleased ? 400 : 200),
    );
    if (!mounted || _isNavigating) return;

    _controller = CameraController(
      backCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted || _isNavigating) {
        await _controller!.dispose();
        return;
      }
      await _controller!.setFlashMode(FlashMode.torch);
      await _controller!.setExposureMode(ExposureMode.locked);

      if (mounted && !_isNavigating) {
        setState(() {});
        _startFingerDetection();
      }
    } on CameraException catch (e) {
      if (mounted)
        _showErrorDialog('Camera Error', e.description ?? 'Unknown error');
    }
  }

  Future<void> _showPlacementGuideDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF12122A),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/finger_placement.png',
                      width: double.infinity,
                      height: 170,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: double.infinity,
                        height: 170,
                        color: const Color(0xFF1E1E3F),
                        child: const Icon(Icons.touch_app,
                            size: 64, color: Color(0xFF667EEA)),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xFF12122A)],
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Place Your Finger Here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  children: [
                    _tip(Icons.touch_app_outlined,
                        'Cover both the camera lens and the flash'),
                    _tip(Icons.front_hand_outlined,
                        'Use your index finger & pad facing down'),
                    _tip(Icons.compress,
                        'Press gently (not too hard, not too light)'),
                    _tip(Icons.do_not_disturb_on_outlined,
                        'Hold completely still for 20 seconds'),
                    _tip(Icons.wb_sunny_outlined,
                        'Flash will glow red through your skin'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Got it',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF667EEA), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _startFingerDetection() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      _controller!.startImageStream((CameraImage image) {
        if (_isNavigating || !mounted) return;

        _frameCounter++;

        final result = _analyzeFrame(image);
        final double brightness = result['brightness']!;
        final double stdDev = result['stdDev']!;

        final bool fingerPresent =
            (brightness > 80 && brightness < 245) && stdDev < 20;

        if (fingerPresent) {
          _stabilityCounter++;
          if (_stabilityCounter >= _stabilityRequired) {
            _isStable = true;
            _isFingerDetected = true;
          }
          if (_isStable) {
            _greenStateCounter++;
            if (_greenStateCounter >= _autoStartDelay) {
              _proceedToMeasurement();
              return;
            }
          }
        } else {
          _stabilityCounter = 0;
          _greenStateCounter = 0;
          _isStable = false;
          _isFingerDetected = false;
        }

        if (_frameCounter % _uiUpdateInterval == 0) {
          final bool snapStable = _isStable;
          final bool snapDetected = _isFingerDetected;
          final int snapBrightness = brightness.round();
          final double snapStdDev = stdDev;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isNavigating) return;
            setState(() {
              _isFingerDetected = snapDetected;
              _isStable = snapStable;
              _currentBrightness = snapBrightness;
              _currentStdDev = snapStdDev;
            });
          });
        }
      });
    } catch (e) {
      print('Stream error: $e');
    }
  }

  Map<String, double> _analyzeFrame(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) {
      return {'brightness': 0.0, 'stdDev': 100.0};
    }
    final int width = image.width;
    final int height = image.height;
    final List<int> yPlane = image.planes[0].bytes;
    final int yStride = image.planes[0].bytesPerRow;
    final int cx = width ~/ 2;
    final int cy = height ~/ 2;
    const int range = 40;

    int sum = 0;
    int count = 0;
    final List<int> samples = [];

    for (int y = cy - range; y < cy + range; y += 2) {
      for (int x = cx - range; x < cx + range; x += 2) {
        if (y >= 0 && y < height && x >= 0 && x < width) {
          final int idx = y * yStride + x;
          if (idx < yPlane.length) {
            sum += yPlane[idx];
            samples.add(yPlane[idx]);
            count++;
          }
        }
      }
    }
    if (count == 0) return {'brightness': 0.0, 'stdDev': 100.0};

    final double brightness = sum / count;
    double sumSq = 0.0;
    for (final int p in samples) {
      final double d = p - brightness;
      sumSq += d * d;
    }
    return {
      'brightness': brightness,
      'stdDev': math.sqrt(sumSq / count),
    };
  }

  // ── UPDATED METHOD WITH PROFILE VALIDATION ──
  void _proceedToMeasurement() {
    if (_isNavigating) return;
    _isNavigating = true;

    final CameraController? ctrl = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // For BP/full scan measurement, validate profile data FIRST
      if (widget.measurementType == 'bp' || widget.measurementType == 'full') {
        final validationResult = await _validateBPProfile();
        if (!validationResult['isValid']) {
          // Validation failed - clean up camera and show error
          if (ctrl != null) {
            try {
              if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
              await ctrl.setFlashMode(FlashMode.off);
              await ctrl.dispose();
            } catch (e) {
              print('[FingerGuide] Camera cleanup error: $e');
            }
          }

          if (mounted) {
            _showProfileError(validationResult['message']);
          }
          return; // Don't navigate
        }
      }

      // Validation passed or HR measurement - dispose camera and navigate
      if (ctrl != null) {
        try {
          if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
          await ctrl.setFlashMode(FlashMode.off);
          await ctrl.dispose();
        } catch (e) {
          print('[FingerGuide] Camera release error: $e');
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) {
              if (widget.measurementType == 'bp') {
                return BPMeasurementScreen(
                  cameras: widget.cameras,
                  cameraAlreadyReleased: true,
                );
              }
              if (widget.measurementType == 'full') {
                return FullScanMeasurementScreen(
                  cameras: widget.cameras,
                  cameraAlreadyReleased: true,
                );
              }
              return HRMeasurementScreen(
                cameras: widget.cameras,
                cameraAlreadyReleased: true,
              );
            },
          ),
        );
      }
    });
  }

  // ── NEW: VALIDATE BP PROFILE ──
  Future<Map<String, dynamic>> _validateBPProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('loggedInUserEmail') ?? '';

    print('[FingerGuide] Validating BP profile for: $email');

    if (email.isEmpty) {
      return {
        'isValid': false,
        'message': 'Please log in to use BP estimation.'
      };
    }

    final ageStr = prefs.getString('${email}_userAge');
    final heightStr = prefs.getString('${email}_userHeight');
    final weightStr = prefs.getString('${email}_userWeight');

    print(
        '[FingerGuide] Profile data: age=$ageStr, height=$heightStr, weight=$weightStr');

    final age = _parseToInt(ageStr);
    final height = _parseToInt(heightStr);
    final weight = _parseToInt(weightStr);

    List<String> missing = [];
    if (age == null) missing.add('Age');
    if (height == null) missing.add('Height');
    if (weight == null) missing.add('Weight');

    if (missing.isNotEmpty) {
      return {
        'isValid': false,
        'message': 'Your profile is missing required information:\n\n'
            '• ${missing.join('\n• ')}\n\n'
            'Please complete your profile:\n'
            'Home → Profile → Edit Profile\n\n'
            'Note: If you just signed up, try logging out and back in.'
      };
    }

    print('[FingerGuide] ✓ Profile validation passed');
    return {'isValid': true};
  }

  // ── NEW: SHOW PROFILE ERROR ──
  void _showProfileError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Color(0xFFF56565)),
            SizedBox(width: 8),
            Expanded(child: Text('Incomplete Profile')),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'OK',
              style: TextStyle(
                  color: Color(0xFF667EEA), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── NEW: PARSE INT HELPER ──
  int? _parseToInt(String? value) {
    if (value == null || value.isEmpty) return null;
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue.round();
    return null;
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isNavigating = true;
    _pulseController.dispose();
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
              ),
              SizedBox(height: 16),
              Text('Starting camera...',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final Color ringColor = _isStable
        ? const Color(0xFF48BB78)
        : _isFingerDetected
            ? const Color(0xFFECC94B)
            : Colors.white54;

    final String ringText = _isStable
        ? 'Hold\nsteady'
        : _isFingerDetected
            ? 'Almost\nready'
            : 'Place\nfinger';

    final Color statusColor = _isStable
        ? const Color(0xFF48BB78)
        : _isFingerDetected
            ? const Color(0xFFECC94B)
            : Colors.white70;

    final String statusText = _isStable
        ? 'Good signal — starting measurement...'
        : _isFingerDetected
            ? 'Almost there. Hold finger steady'
            : 'Cover camera & flash with your fingertip';

    final IconData statusIcon = _isStable
        ? Icons.check_circle_rounded
        : _isFingerDetected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          _isNavigating = true;
                          Navigator.pop(context);
                        },
                      ),
                      const Text(
                        'Position Your Finger',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: _buildRing(ringColor, ringText),
                        ),
                      ),
                      _buildPanel(statusIcon, statusColor, statusText),
                      const SizedBox(height: 20),
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

  Widget _buildRing(Color color, String text) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 176,
      height: 176,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(_isStable ? 0.5 : 0.2),
            blurRadius: _isStable ? 30 : 10,
            spreadRadius: _isStable ? 5 : 0,
          ),
        ],
      ),
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildPanel(IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isStable
              ? const Color(0xFF48BB78).withOpacity(0.45)
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(icon, key: ValueKey(icon), color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          _buildStep('1', Icons.touch_app,
              'Cover the rear camera and flash with your index fingertip'),
          const SizedBox(height: 8),
          _buildStep('2', Icons.light_mode,
              'Apply gentle even pressure and the flash glows red through skin'),
          const SizedBox(height: 8),
          _buildStep('3', Icons.timer,
              'Hold still. Measurement starts automatically when signal is good'),
        ],
      ),
    );
  }

  Widget _buildStep(String num, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: Colors.white30, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}
