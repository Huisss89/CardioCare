import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../profile/profile_screen.dart';
import 'dashboard_screen.dart';
import '../../history_screen.dart';
import '../../trends_screen.dart';
import '../../finger_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // FIX: Use PageStorageKey to force remount/reinitialization of screens when switching tabs.
  // This will ensure initState() is called again for Profile/Dashboard if they are navigated away from
  // and back to within the HomeScreen lifecycle, but the main goal is guaranteeing fresh data on app launch after login.
  final List<Widget> _screens = [
    const DashboardScreen(cameras: [], key: PageStorageKey('Dashboard')),
    const HistoryScreen(key: PageStorageKey('History')),
    const TrendsScreen(key: PageStorageKey('Trends')),
    const ProfileScreen(cameras: [], key: PageStorageKey('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    // Rebuild the screens list every time to ensure the correct camera objects are passed
    final List<Widget> screens = [
      DashboardScreen(
          cameras: widget.cameras, key: const PageStorageKey('Dashboard')),
      const HistoryScreen(key: PageStorageKey('History')),
      const TrendsScreen(key: PageStorageKey('Trends')),
      ProfileScreen(
          cameras: widget.cameras, key: const PageStorageKey('Profile')),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0),
                _buildNavItem(Icons.history_rounded, 'History', 1),
                _buildNavItem(Icons.trending_up_rounded, 'Trends', 2),
                _buildNavItem(Icons.person_rounded, 'Profile', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('userEmail') ?? "unknown";

        await FirebaseAnalytics.instance.logEvent(
          name: "tab_selected",
          parameters: {
            "tab_name": label,
            "is_logged_in": email != "unknown" ? 1 : 0,
          },
        );

        setState(() => _selectedIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)])
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF718096),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
