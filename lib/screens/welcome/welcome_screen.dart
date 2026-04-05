import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'welcome_page_data.dart';
import 'modern_welcome_page.dart';
import '../auth/forgot_password_screen.dart';
import '../../authentication.dart';
import 'package:http/http.dart' as http;

class WelcomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const WelcomeScreen({super.key, required this.cameras});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<WelcomePageData> _pages = [
    WelcomePageData(
      animationUrl: 'assets/animations/welcome.json',
      title: 'Welcome to CardioCare',
      description: 'Let\'s start your health journey today with us!',
      gradientColors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    ),
    WelcomePageData(
      animationUrl: 'assets/animations/heart_monitor.json',
      title: '1-Tap HR/HRV Monitoring',
      description:
          'Measure your heart rate and heart rate variability instantly',
      gradientColors: [const Color(0xFFFF6B9D), const Color(0xFFFFC3A0)],
    ),
    WelcomePageData(
      animationUrl: 'assets/animations/blood_pressure.json',
      title: 'Blood Pressure Estimation',
      description: 'Estimate your blood pressure using advanced PPG technology',
      gradientColors: [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
    ),
    WelcomePageData(
      animationUrl: 'assets/animations/bp_log.json',
      title: 'Log Your Blood Pressure',
      description: 'Track your blood pressure readings over time',
      gradientColors: [const Color(0xFFFA709A), const Color(0xFFFEE140)],
    ),
    WelcomePageData(
      animationUrl: 'assets/animations/trends.json',
      title: 'Trends & Insights',
      description: 'Get personalized insights and health recommendations',
      gradientColors: [const Color(0xFF30CDC9), const Color(0xFF48E5C2)],
    ),
  ];

  Future<void> _completeWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? 'guest';

    final bool wasSkipped = _currentPage < _pages.length - 1;

    await FirebaseAnalytics.instance.logEvent(
      name: 'welcome_completed',
      parameters: {
        'skipped': wasSkipped ? 1 : 0,
        'user_email': email,
      },
    );

    await prefs.setBool('hasSeenWelcome', true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(cameras: widget.cameras),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) =>
                ModernWelcomePage(data: _pages[index]),
          ),
          // Skip button
          Positioned(
            top: 50,
            right: 20,
            child: _currentPage < _pages.length - 1
                ? TextButton(
                    onPressed: _completeWelcome,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Dots + Get Started
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_currentPage == _pages.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: _completeWelcome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667EEA),
                        minimumSize: const Size(double.infinity, 58),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
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
