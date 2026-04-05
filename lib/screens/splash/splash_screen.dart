import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cardio_care/screens/welcome/welcome_screen.dart';
import 'package:cardio_care/screens/home/home_screen.dart';
import 'package:cardio_care/authentication.dart';

class SplashScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SplashScreen({super.key, required this.cameras});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  late AnimationController _logoScaleCtrl;
  late AnimationController _logoFadeCtrl;
  late AnimationController _textFadeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _orb1Ctrl;
  late AnimationController _orb2Ctrl;
  late AnimationController _ringCtrl;
  late AnimationController _exitCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _pulse;
  late Animation<double> _orb1;
  late Animation<double> _orb2;
  late Animation<double> _ring;
  late Animation<double> _exitFade;
  late Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    _logoScaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale =
        CurvedAnimation(parent: _logoScaleCtrl, curve: Curves.elasticOut);

    _logoFadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _logoFade = CurvedAnimation(parent: _logoFadeCtrl, curve: Curves.easeIn);

    _textFadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textFade = CurvedAnimation(parent: _textFadeCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textFadeCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.10)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _orb1Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _orb1 = Tween<double>(begin: -12, end: 12)
        .animate(CurvedAnimation(parent: _orb1Ctrl, curve: Curves.easeInOut));

    _orb2Ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _orb2 = Tween<double>(begin: 10, end: -10)
        .animate(CurvedAnimation(parent: _orb2Ctrl, curve: Curves.easeInOut));

    _ringCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
    _ring = Tween<double>(begin: 0, end: 2 * math.pi).animate(_ringCtrl);

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _exitFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
    _exitScale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    _logoFadeCtrl.forward();
    _logoScaleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 350));
    _textFadeCtrl.forward();

    // Load prefs in background while animating
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = false;
    // final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    await Future.delayed(const Duration(milliseconds: 3000));

    await _exitCtrl.forward();

    if (!mounted) return;

    Widget destination;
    if (!hasSeenWelcome) {
      destination = WelcomeScreen(cameras: widget.cameras);
    } else if (!isLoggedIn) {
      destination = LoginScreen(cameras: widget.cameras);
    } else {
      destination = HomeScreen(cameras: widget.cameras);
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoScaleCtrl.dispose();
    _logoFadeCtrl.dispose();
    _textFadeCtrl.dispose();
    _pulseCtrl.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _ringCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_exitFade, _exitScale]),
      builder: (context, _) {
        return FadeTransition(
          opacity: _exitFade,
          child: Transform.scale(
            scale: _exitScale.value,
            child: Scaffold(
              body: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                ),
                child: Stack(
                  children: [
                    // ── Floating orbs ──────────────────────────────────
                    _buildOrb(
                      anim: _orb1,
                      color: const Color(0xFF9F7AEA).withOpacity(0.35),
                      size: 220,
                      left: -60,
                      top: size.height * 0.08,
                    ),
                    _buildOrb(
                      anim: _orb2,
                      color: const Color(0xFF4FACFE).withOpacity(0.25),
                      size: 180,
                      right: -50,
                      bottom: size.height * 0.18,
                    ),
                    _buildOrb(
                      anim: _orb1,
                      color: const Color(0xFFFF6B9D).withOpacity(0.18),
                      size: 120,
                      right: 30,
                      top: size.height * 0.12,
                    ),
                    _buildOrb(
                      anim: _orb2,
                      color: const Color(0xFF764BA2).withOpacity(0.30),
                      size: 90,
                      left: 20,
                      bottom: size.height * 0.22,
                    ),

                    // ── Centre content ─────────────────────────────────
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogoArea(),
                          const SizedBox(height: 32),
                          SlideTransition(
                            position: _textSlide,
                            child: FadeTransition(
                              opacity: _textFade,
                              child: Column(
                                children: [
                                  const Text(
                                    'CardioCare',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                      height: 1.1,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 16,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Your Health Companion',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withOpacity(0.92),
                                        letterSpacing: 0.8,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                          FadeTransition(
                            opacity: _textFade,
                            child: _buildLoadingDots(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoArea() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoScale, _logoFade, _pulse, _ring]),
      builder: (_, __) {
        return FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _ring.value,
                    child: CustomPaint(
                      size: const Size(172, 172),
                      painter: _DashedRingPainter(
                        color: Colors.white.withOpacity(0.22),
                        strokeWidth: 1.5,
                        dashCount: 20,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -_ring.value * 0.5,
                    child: CustomPaint(
                      size: const Size(136, 136),
                      painter: _DashedRingPainter(
                        color: Colors.white.withOpacity(0.30),
                        strokeWidth: 2,
                        dashCount: 10,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF6B9D).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrb({
    required Animation<double> anim,
    required Color color,
    required double size,
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Positioned(
        left: left,
        right: right,
        top: top != null ? top + anim.value : null,
        bottom: bottom != null ? bottom + anim.value : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: size * 0.5,
                spreadRadius: size * 0.05,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final progress = (_pulseCtrl.value + i * 0.33) % 1.0;
            final scale = 0.6 + 0.4 * math.sin(progress * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.4 + 0.5 * scale),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Dashed ring painter ───────────────────────────────────────────────────────
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final dashAngle = (2 * math.pi) / dashCount;
    const gapFraction = 0.42;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashCount != dashCount;
}
