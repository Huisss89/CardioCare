import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'welcome_page_data.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

class ModernWelcomePage extends StatefulWidget {
  final WelcomePageData data;
  const ModernWelcomePage({super.key, required this.data});

  @override
  State<ModernWelcomePage> createState() => _ModernWelcomePageState();
}

class _ModernWelcomePageState extends State<ModernWelcomePage>
    with TickerProviderStateMixin {
  // ── Lottie state ──────────────────────────────────────────────
  bool _lottieLoaded = false;
  bool _lottieFailed = false;

  // ── Animations ────────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _floatCtrl;

  late Animation<double> _pulse;
  late Animation<double> _rotate;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 220), vsync: this);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.10)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _rotateCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
    _rotate = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -10, end: 10)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ── Per-page icon for fallback only ───────────────────────────
  // This icon only shows when Lottie completely fails to load.
  IconData get _pageIcon {
    final url = widget.data.animationUrl;
    if (url.contains('welcome')) return Icons.favorite_rounded;
    if (url.contains('heart_monitor')) return Icons.monitor_heart_rounded;
    if (url.contains('blood_pressure')) return Icons.water_drop_rounded;
    if (url.contains('bp_log')) return Icons.edit_note_rounded;
    if (url.contains('trends')) return Icons.show_chart_rounded;
    return Icons.health_and_safety_rounded;
  }

  Future<void> _wakeUpServices() async {
    for (final url in AppConfig.warmupUrls) {
      http.get(Uri.parse(url)).catchError((_) {});
    }
  }

  // ── Fallback: only shown when Lottie fails completely ─────────
  // No white circle, no frosted glass — just clean rings + icon
  // that matches the page gradient.
  Widget _buildAnimatedFallback() {
    final c1 = widget.data.gradientColors[0];

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _rotate, _float]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _float.value),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating dashed ring
              Transform.rotate(
                angle: _rotate.value,
                child: CustomPaint(
                  size: const Size(210, 210),
                  painter: _DashedRingPainter(
                    color: Colors.white.withOpacity(0.20),
                    strokeWidth: 1.5,
                    dashCount: 24,
                  ),
                ),
              ),
              // Inner counter-rotating ring
              Transform.rotate(
                angle: -_rotate.value * 0.55,
                child: CustomPaint(
                  size: const Size(160, 160),
                  painter: _DashedRingPainter(
                    color: Colors.white.withOpacity(0.30),
                    strokeWidth: 2,
                    dashCount: 12,
                  ),
                ),
              ),
              // Pulsing soft glow — no hard edges, no white fill
              Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Icon — transparent background, just the icon + subtle glow
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Subtle tinted border only — no solid fill
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c1.withOpacity(0.4),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(_pageIcon, color: Colors.white, size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main animation area ────────────────────────────────────────
  Widget _buildAnimationArea() {
    // Lottie failed entirely → show clean fallback
    if (_lottieFailed) return _buildAnimatedFallback();

    return SizedBox(
      width: 260,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Loading placeholder: simple rings, no white circle ──
          if (!_lottieLoaded)
            AnimatedBuilder(
              animation: _rotate,
              builder: (_, __) => Transform.rotate(
                angle: _rotate.value,
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _DashedRingPainter(
                    color: Colors.white.withOpacity(0.18),
                    strokeWidth: 1.5,
                    dashCount: 20,
                  ),
                ),
              ),
            ),

          // ── Lottie from local asset ─────────────────────────────
          // Uses Lottie.asset instead of Lottie.network.
          // No background container wrapping it — renders directly
          // over the gradient so there is zero white bleed-through.
          AnimatedOpacity(
            opacity: _lottieLoaded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Lottie.asset(
              widget.data.animationUrl,
              width: 260,
              height: 260,
              fit: BoxFit.contain,
              frameRate: FrameRate.max,
              options: LottieOptions(enableMergePaths: true),
              onLoaded: (_) {
                if (mounted) setState(() => _lottieLoaded = true);
              },
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_lottieFailed) {
                    setState(() => _lottieFailed = true);
                  }
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _wakeUpServices();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.data.gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimationArea(),
                const SizedBox(height: 2),
                Text(
                  widget.data.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.data.description,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white.withOpacity(0.9),
                    height: 0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashed ring painter ────────────────────────────────────────────────────
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
