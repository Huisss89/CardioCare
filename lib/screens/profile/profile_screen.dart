import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import '../../authentication.dart';
import '../../reminder_screen.dart';
import '../../export_data_screen.dart';
import '../../clear_records_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ProfileScreen({super.key, required this.cameras});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'User';
  String _userEmail = '';
  String _userAge = '';
  String _userGender = '';
  String _userWeight = '';
  String _userHeight = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load data when tab is re-visited
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the currently logged-in user email
    final loggedInUserEmail = prefs.getString('loggedInUserEmail') ?? '';

    if (mounted) {
      setState(() {
        _userEmail = loggedInUserEmail;

        // If user is logged in, retrieve their specific data using email prefix
        if (loggedInUserEmail.isNotEmpty) {
          _userName =
              prefs.getString('${loggedInUserEmail}_userName') ?? 'User';
          _userAge = prefs.getString('${loggedInUserEmail}_userAge') ?? '';
          _userGender =
              prefs.getString('${loggedInUserEmail}_userGender') ?? '';
          _userWeight =
              prefs.getString('${loggedInUserEmail}_userWeight') ?? '';
          _userHeight =
              prefs.getString('${loggedInUserEmail}_userHeight') ?? '';
        } else {
          // Fallback if no logged-in user
          _userName = 'User';
          _userAge = '';
          _userGender = '';
          _userWeight = '';
          _userHeight = '';
        }
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedInUserEmail');
      // Ensure Firebase signs out correctly
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => LoginScreen(cameras: widget.cameras)),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header - Full width gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFF5F7FA),
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667EEA),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail.isNotEmpty ? _userEmail : 'Not logged in',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    if (_userAge.isNotEmpty || _userGender.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_userAge.isNotEmpty ? "$_userAge years" : ""} ${_userGender.isNotEmpty && _userAge.isNotEmpty ? "•" : ""} $_userGender',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_userWeight.isNotEmpty || _userHeight.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Weight: $_userWeight kg • Height: $_userHeight cm',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingCard(
                      'Edit Profile',
                      'Update your personal information',
                      Icons.person_outline,
                      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                      () async {
                        final refreshed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              cameras: widget.cameras,
                              userEmail: _userEmail,
                              userName: _userName,
                              userAge: _userAge,
                              userGender: _userGender,
                              userWeight: _userWeight,
                              userHeight: _userHeight,
                            ),
                          ),
                        );
                        if (refreshed == true && mounted) {
                          _loadUserData();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      'Reminders',
                      'Health checks & medicine reminders',
                      Icons.notifications_outlined,
                      [const Color(0xFFED8936), const Color(0xFFDD6B20)],
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReminderScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      'Export Data',
                      'Download your health records',
                      Icons.download_outlined,
                      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExportDataScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Clear Data — now opens the bottom sheet
                    _buildSettingCard(
                      'Clear Data',
                      'Select and delete health records',
                      Icons.delete_outline,
                      [const Color(0xFFF56565), const Color(0xFFC53030)],
                      () => showClearRecordsSheet(context),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFF56565), width: 2),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Color(0xFFF56565)),
                            SizedBox(width: 8),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Color(0xFFF56565),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Center(
                      child: Text(
                        'CardioCare v1.0.0',
                        style: TextStyle(
                          color: Color(0xFFA0AEC0),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    String title,
    String description,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Color(0xFFCBD5E0)),
          ],
        ),
      ),
    );
  }
}
