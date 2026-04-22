// finger_guide_screen.dart
//
// Design  : old code (3-state ring, radial gradient, animated panel)
// Detection: new code (YUV→RGB red-channel dominance, FingerLossMixin)

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/camera_utils.dart';
import 'screens/measurement/bp/bp_measurement_screen.dart';
import 'screens/measurement/hr/hr_measurement_screen.dart';
import 'screens/measurement/full_scan/full_scan_measurement_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  IMAGE PROCESSING  (ported from Java ImageProcessing.java)
//
//  Converts YUV420SP (NV21) bytes → RGB, then returns the average of
//  one channel across the whole frame.
//    type 1 = Red
//    type 2 = Blue
//    type 3 = Green
//
//  WHY RED CHANNEL?
//  Blood absorbs green/blue light but reflects red. When the torch shines
//  through a fingertip, the red channel average is HIGH (> 150) and stays
//  very stable. Any other object (desk, air, cloth) will have a much lower
//  or noisier red average.
// ─────────────────────────────────────────────────────────────────────────────

const int _TYPE_RED = 1;
const int _TYPE_BLUE = 2;
const int _TYPE_GREEN = 3;

int _decodeYUV420SPtoColorSum(
    List<int> yuv420sp, int width, int height, int type) {
  final int frameSize = width * height;
  int sumR = 0, sumG = 0, sumB = 0;

  for (int j = 0, yp = 0; j < height; j++) {
    int uvp = frameSize + (j >> 1) * width;
    int u = 0, v = 0;

    for (int i = 0; i < width; i++, yp++) {
      int y = (yuv420sp[yp] & 0xff) - 16;
      if (y < 0) y = 0;

      if ((i & 1) == 0) {
        v = (yuv420sp[uvp++] & 0xff) - 128;
        u = (yuv420sp[uvp++] & 0xff) - 128;
      }

      final int y1192 = 1192 * y;
      int r = y1192 + 1634 * v;
      int g = y1192 - 833 * v - 400 * u;
      int b = y1192 + 2066 * u;

      if (r < 0)
        r = 0;
      else if (r > 262143) r = 262143;
      if (g < 0)
        g = 0;
      else if (g > 262143) g = 262143;
      if (b < 0)
        b = 0;
      else if (b > 262143) b = 262143;

      sumR += (r >> 10) & 0xff;
      sumG += (g >> 10) & 0xff;
      sumB += (b >> 10) & 0xff;
    }
  }

  switch (type) {
    case _TYPE_RED:
      return sumR;
    case _TYPE_BLUE:
      return sumB;
    case _TYPE_GREEN:
      return sumG;
    default:
      return sumR;
  }
}

/// Returns the average of one colour channel across the whole frame (0–255).
double decodeYUV420SPtoColorAvg(
    List<int> yuv420sp, int width, int height, int type) {
  final int frameSize = width * height;
  if (frameSize == 0) return 0;
  return _decodeYUV420SPtoColorSum(yuv420sp, width, height, type) / frameSize;
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETECTION THRESHOLDS
//
//  With torch ON + finger covering lens:
//    Red   > 150   — backlit blood tissue is very red
//    Green < 100   — blood absorbs green
//    R - G > 80    — strong red dominance = real finger
// ─────────────────────────────────────────────────────────────────────────────
const double _kMinRedAvg = 150.0;
const double _kMaxGreenAvg = 100.0;
const double _kMinRedGreenGap = 80.0;
const int _kFramesToConfirm = 10; // consecutive good frames → proceed
const int _kBadFrameLimit = 20;   // consecutive bad frames  → reprompt
const int _kUiInterval = 4;       // setState every N frames

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Flattens Flutter's multi-plane YUV420 CameraImage into a single NV21
/// byte list that [decodeYUV420SPtoColorAvg] expects.
List<int>? _toNV21(CameraImage image) {
  if (image.format.group != ImageFormatGroup.yuv420) return null;
  if (image.planes.length < 3) return null;

  final int w = image.width;
  final int h = image.height;
  final frameSize = w * h;

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final nv21 = List<int>.filled(frameSize + (frameSize ~/ 2), 0);

  for (int row = 0; row < h; row++) {
    final src = row * yPlane.bytesPerRow;
    final dst = row * w;
    for (int col = 0; col < w; col++) {
      final s = src + col;
      if (s < yPlane.bytes.length) nv21[dst + col] = yPlane.bytes[s];
    }
  }

  final uvH = h ~/ 2;
  final uvW = w ~/ 2;
  for (int row = 0; row < uvH; row++) {
    for (int col = 0; col < uvW; col++) {
      final vIdx = row * vPlane.bytesPerRow + col * (vPlane.bytesPerPixel ?? 1);
      final uIdx = row * uPlane.bytesPerRow + col * (uPlane.bytesPerPixel ?? 1);
      final dst = frameSize + row * w + col * 2;
      if (vIdx < vPlane.bytes.length) nv21[dst] = vPlane.bytes[vIdx];
      if (uIdx < uPlane.bytes.length) nv21[dst + 1] = uPlane.bytes[uIdx];
    }
  }

  return nv21;
}

/// Returns true when the frame looks like a blood-perfused fingertip
/// covering the lit lens.
bool isLensCovered(CameraImage image) {
  final nv21 = _toNV21(image);
  if (nv21 == null) return false;

  final red =
      decodeYUV420SPtoColorAvg(nv21, image.width, image.height, _TYPE_RED);
  final green =
      decodeYUV420SPtoColorAvg(nv21, image.width, image.height, _TYPE_GREEN);

  return red >= _kMinRedAvg &&
      green <= _kMaxGreenAvg &&
      (red - green) >= _kMinRedGreenGap;
}

// ─────────────────────────────────────────────────────────────────────────────
//  FINGER LOSS MIXIN
//
//  Add to any measurement screen State to detect mid-measurement finger loss.
//
//  Usage:
//    class _HRMeasurementScreenState extends State<HRMeasurementScreen>
//        with FingerLossMixin {
//
//      void _onFrame(CameraImage image) {
//        checkCoverage(image, context, widget.cameras, 'hr');
//        // ... rest of your processing unchanged
//      }
//    }
// ─────────────────────────────────────────────────────────────────────────────
mixin FingerLossMixin<T extends StatefulWidget> on State<T> {
  int _badFrames = 0;
  bool _lossNavigating = false;

  void checkCoverage(
    CameraImage image,
    BuildContext context,
    List<CameraDescription> cameras,
    String measurementType,
  ) {
    if (_lossNavigating) return;

    if (!isLensCovered(image)) {
      _badFrames++;
      if (_badFrames >= _kBadFrameLimit) {
        _lossNavigating = true;
        _reprompt(context, cameras, measurementType);
      }
    } else {
      _badFrames = 0;
    }
  }

  void _reprompt(
    BuildContext context,
    List<CameraDescription> cameras,
    String measurementType,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFF12122A),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFECC94B)),
            SizedBox(width: 8),
            Text('Finger Removed',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: const Text(
            'Your finger left the camera.\nPlease reposition and try again.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => FingerGuideScreen(
                      cameras: cameras,
                      cameraAlreadyReleased: false,
                      measurementType: measurementType,
                    ),
                  ),
                );
              },
              child: const Text('Reposition',
                  style: TextStyle(
                      color: Color(0xFF667EEA), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FINGER GUIDE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class FingerGuideScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool cameraAlreadyReleased;
  final String measurementType; // 'hr' | 'bp' | 'full'

  const FingerGuideScreen({
    super.key,
    required this.cameras,
    this.cameraAlreadyReleased = false,
    this.measurementType = 'hr',
  });

  @override
  State<FingerGuideScreen> createState() => _FingerGuideScreenState();
}

class _FingerGuideScreenState extends State<FingerGuideScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;

  // ── Detection state (3 levels matching old UI) ────────────────────────────
  // Level 0: no finger   → white  "Place finger"
  // Level 1: partial/red seen but not yet confirmed → yellow "Almost ready"
  // Level 2: confirmed   → green  "Hold steady"
  bool _isFingerDetected = false; // level ≥ 1 (red seen this frame)
  bool _isStable = false;         // level 2  (kFramesToConfirm consecutive)

  int _goodFrames = 0;
  int _frameCount = 0;
  bool _isNavigating = false;

  // How many more consecutive stable frames until we auto-navigate
  static const int _kAutoStartDelay = 9; // frames after stable confirmed
  int _autoStartCounter = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showGuideDialog();
    });
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

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    final back = widget.cameras.firstWhereOrNull(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (back == null) {
      _showErrorDialog('Camera Error', 'Back camera not found.');
      return;
    }

    await Future.delayed(
        Duration(milliseconds: widget.cameraAlreadyReleased ? 400 : 200));
    if (!mounted || _isNavigating) return;

    _controller = CameraController(
      back,
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
      // Let auto-exposure adapt to the torch light BEFORE locking.
      // Locking immediately captures a dark "normal scene" exposure value.
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted || _isNavigating) return;
      // Boost exposure offset so the preview is visible while the finger
      // is being positioned (range is device-dependent, typically -4..+4 EV).
      try {
        final double minEV = await _controller!.getMinExposureOffset();
        final double maxEV = await _controller!.getMaxExposureOffset();
        // Pick +1 EV, clamped to whatever the device supports.
        final double targetEV = 1.0.clamp(minEV, maxEV);
        await _controller!.setExposureOffset(targetEV);
      } catch (_) {
        // Some devices don't support offset — safe to ignore.
      }
      // Now lock so the exposure stays stable during detection.
      await _controller!.setExposureMode(ExposureMode.locked);
      if (mounted && !_isNavigating) {
        setState(() {});
        _startStream();
      }
    } on CameraException catch (e) {
      if (mounted)
        _showErrorDialog('Camera Error', e.description ?? 'Unknown error');
    }
  }

  Future<void> _releaseCamera(CameraController? ctrl) async {
    if (ctrl == null) return;
    try {
      if (ctrl.value.isStreamingImages) await ctrl.stopImageStream();
      await ctrl.setFlashMode(FlashMode.off);
      await ctrl.dispose();
    } catch (_) {}
  }

  // ── Image stream — RGB detection ─────────────────────

  void _startStream() {
    _controller?.startImageStream((CameraImage image) {
      if (_isNavigating || !mounted) return;
      _frameCount++;

      final nv21 = _toNV21(image);
      if (nv21 == null) return;

      final w = image.width;
      final h = image.height;
      final red = decodeYUV420SPtoColorAvg(nv21, w, h, _TYPE_RED);
      final green = decodeYUV420SPtoColorAvg(nv21, w, h, _TYPE_GREEN);

      // Primary detection: red-channel dominance
      final bool covered = red >= _kMinRedAvg &&
          green <= _kMaxGreenAvg &&
          (red - green) >= _kMinRedGreenGap;

      // "Almost ready": red is rising but not yet fully confirmed
      // (red > 100 and starting to dominate) — maps to old yellow state
      final bool partial = !covered &&
          red > 100 &&
          (red - green) > 30;

      if (covered) {
        _goodFrames++;
        if (_goodFrames >= _kFramesToConfirm) {
          // Finger confirmed — now count auto-start frames
          _autoStartCounter++;
          if (_autoStartCounter >= _kAutoStartDelay) {
            _proceed();
            return;
          }
        }
      } else {
        _goodFrames = 0;
        _autoStartCounter = 0;
      }

      if (_frameCount % _kUiInterval == 0) {
        final bool snapStable = _goodFrames >= _kFramesToConfirm;
        final bool snapDetected = covered || partial;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isNavigating) return;
          setState(() {
            _isStable = snapStable;
            _isFingerDetected = snapDetected;
          });
        });
      }
    });
  }

  // ── Proceed ───────────────────────────────────────────────────────────────

  void _proceed() {
    if (_isNavigating) return;
    _isNavigating = true;

    final ctrl = _controller;
    if (mounted) setState(() => _controller = null);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.measurementType == 'bp' || widget.measurementType == 'full') {
        final result = await _validateBPProfile();
        if (!result['isValid']) {
          await _releaseCamera(ctrl);
          if (mounted) _showProfileError(result['message']);
          return;
        }
      }
      await _releaseCamera(ctrl);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) {
          if (widget.measurementType == 'bp') {
            return BPMeasurementScreen(
                cameras: widget.cameras, cameraAlreadyReleased: true);
          }
          if (widget.measurementType == 'full') {
            return FullScanMeasurementScreen(
                cameras: widget.cameras, cameraAlreadyReleased: true);
          }
          return HRMeasurementScreen(
              cameras: widget.cameras, cameraAlreadyReleased: true);
        }),
      );
    });
  }

  // ── Profile validation ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _validateBPProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('loggedInUserEmail') ?? '';
    if (email.isEmpty) {
      return {
        'isValid': false,
        'message': 'Please log in to use BP estimation.'
      };
    }
    final age = _parseToInt(prefs.getString('${email}_userAge'));
    final height = _parseToInt(prefs.getString('${email}_userHeight'));
    final weight = _parseToInt(prefs.getString('${email}_userWeight'));
    final missing = [
      if (age == null) 'Age',
      if (height == null) 'Height',
      if (weight == null) 'Weight',
    ];
    if (missing.isNotEmpty) {
      return {
        'isValid': false,
        'message': 'Your profile is missing required information:\n\n'
            '• ${missing.join('\n• ')}\n\n'
            'Please complete your profile:\n'
            'Home → Profile → Edit Profile\n\n'
            'Note: If you just signed up, try logging out and back in.',
      };
    }
    return {'isValid': true};
  }

  int? _parseToInt(String? v) {
    if (v == null || v.isEmpty) return null;
    return int.tryParse(v) ?? double.tryParse(v)?.round();
  }

  void _showProfileError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF12122A),
        title: const Row(children: [
          Icon(Icons.warning_rounded, color: Color(0xFFF56565)),
          SizedBox(width: 8),
          Expanded(
              child: Text('Incomplete Profile',
                  style: TextStyle(color: Colors.white))),
        ]),
        content: SingleChildScrollView(
          child: Text(message,
              style: const TextStyle(color: Colors.white70, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('OK',
                style: TextStyle(
                    color: Color(0xFF667EEA), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Guide dialog ──────────────────────────────────────────────────────────

  Future<void> _showGuideDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
              child: Column(children: [
                _tip(Icons.touch_app_outlined,
                    'Cover both the camera lens and the flash completely'),
                _tip(Icons.front_hand_outlined,
                    'Use your index fingertip, pad facing down'),
                _tip(Icons.compress,
                    'Press gently — not too hard, not too light'),
                _tip(Icons.do_not_disturb_on_outlined,
                    'Hold completely still for 20 seconds'),
                _tip(Icons.wb_sunny_outlined,
                    'Flash glows red through your skin — that is normal'),
              ]),
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
                  child: const Text('Got it',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tip(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF667EEA), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
            ),
          ],
        ),
      );

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

  // ── Build ─────────────────────────────────────────────────────────────────

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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF667EEA))),
              SizedBox(height: 16),
              Text('Starting camera...',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // ── 3-state colours ────────────────────────
    final Color ringColor = _isStable
        ? const Color(0xFF48BB78)         // green  — confirmed
        : _isFingerDetected
            ? const Color(0xFFECC94B)     // yellow — partial / almost
            : Colors.white54;             // white  — no finger

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
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.65),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white),
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
                      // Detection ring
                      Expanded(
                        child: Center(child: _buildRing(ringColor, ringText)),
                      ),
                      // Status + steps panel
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

  // ── Widgets ───────────────────────────

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
              'Apply gentle even pressure — flash glows red through your skin'),
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
            gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
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