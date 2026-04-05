import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class EditProfileScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String userEmail;
  final String userName;
  final String userAge;
  final String userGender;
  final String userWeight;
  final String userHeight;

  const EditProfileScreen({
    super.key,
    required this.cameras,
    required this.userEmail,
    required this.userName,
    required this.userAge,
    required this.userGender,
    required this.userWeight,
    required this.userHeight,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late String _selectedGender;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // ── Password fields ──────────────────────────────────────────────────────
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isPasswordSectionExpanded = false;
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _ageController = TextEditingController(text: widget.userAge);
    _weightController = TextEditingController(text: widget.userWeight);
    _heightController = TextEditingController(text: widget.userHeight);
    _selectedGender = widget.userGender.isNotEmpty ? widget.userGender : 'Male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Network Check Helper ─────────────────────────────────────────────────
  Future<bool> _hasInternetConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ── No Internet Dialog ───────────────────────────────────────────────────
  Future<void> _showNoInternetDialog({required String action}) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF56565).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFF56565),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'No Internet\nConnection',
                style: TextStyle(
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Unable to $action because you are currently offline.',
              style: const TextStyle(
                color: Color(0xFF4A5568),
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF56565).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFF56565).withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFF56565)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please check your Wi-Fi or mobile data and try again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFF56565).withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Try Again Later',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to update profile.'),
            backgroundColor: Color(0xFFF56565),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // ── Check internet before saving profile ─────────────────────────────
    final bool isConnected = await _hasInternetConnection();
    if (!isConnected) {
      await _showNoInternetDialog(action: 'save your profile changes');
      return;
    }
    // ─────────────────────────────────────────────────────────────────────

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final age = int.tryParse(_ageController.text) ?? 0;
      final weight = double.tryParse(_weightController.text) ?? 0.0;
      final height = double.tryParse(_heightController.text) ?? 0.0;
      final gender = _selectedGender;

      await user.updateDisplayName(name);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': user.email ?? widget.userEmail,
        'age': age,
        'gender': gender,
        'weight': weight,
        'height': height,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      final userEmail =
          prefs.getString('loggedInUserEmail') ?? widget.userEmail;
      await prefs.setString('${userEmail}_userName', name);
      await prefs.setString('${userEmail}_userAge', age.toString());
      await prefs.setString('${userEmail}_userGender', gender);
      await prefs.setString(
          '${userEmail}_userWeight', weight.toStringAsFixed(0));
      await prefs.setString(
          '${userEmail}_userHeight', height.toStringAsFixed(0));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF48BB78),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: const Color(0xFFF56565),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Change Password ───────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showSnackBar('You must be logged in to change your password.',
          isError: true);
      return;
    }

    // ── Check internet before changing password ──────────────────────────
    final bool isConnected = await _hasInternetConnection();
    if (!isConnected) {
      await _showNoInternetDialog(action: 'update your password');
      return;
    }
    // ─────────────────────────────────────────────────────────────────────

    setState(() => _isPasswordLoading = true);

    try {
      // Re-authenticate with current password first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      // Clear fields and collapse section
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isPasswordSectionExpanded = false);

      _showSnackBar('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'Current password is incorrect.';
          break;
        case 'weak-password':
          message = 'New password is too weak. Use at least 8 characters.';
          break;
        case 'requires-recent-login':
          message = 'Please log out and log back in, then try again.';
          break;
        default:
          message = e.message ?? 'Failed to change password.';
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFF56565) : const Color(0xFF48BB78),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Gradient header with back button
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 32,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update your personal information',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Profile Form ──────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hint: 'Enter your name',
                                icon: Icons.person_outline_rounded,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Name is required'
                                        : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _ageController,
                                label: 'Age',
                                hint: 'e.g. 25',
                                icon: Icons.cake_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Age is required';
                                  final n = int.tryParse(v);
                                  if (n == null || n < 1 || n > 150) {
                                    return 'Enter a valid age (1-150)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildGenderSelector(),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _weightController,
                                label: 'Weight (kg)',
                                hint: 'e.g. 70',
                                icon: Icons.monitor_weight_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Weight is required';
                                  final n = double.tryParse(v);
                                  if (n == null || n < 20 || n > 300) {
                                    return 'Enter a valid weight (20-300 kg)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _heightController,
                                label: 'Height (cm)',
                                hint: 'e.g. 170',
                                icon: Icons.height_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Height is required';
                                  final n = double.tryParse(v);
                                  if (n == null || n < 50 || n > 250) {
                                    return 'Enter a valid height (50-250 cm)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              // Email (read-only)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.email_outlined,
                                        color: Colors.grey[600], size: 22),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Email',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            widget.userEmail,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF2D3748),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.lock_outline,
                                        size: 18, color: Colors.grey[400]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Save profile button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded, size: 22),
                                      SizedBox(width: 10),
                                      Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Change Password Section ───────────────────────────────
                  _buildChangePasswordSection(),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Change Password Card ──────────────────────────────────────────────────
  Widget _buildChangePasswordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header toggle
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(
                () => _isPasswordSectionExpanded = !_isPasswordSectionExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update your account password',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isPasswordSectionExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF718096),
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable password form
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isPasswordSectionExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Form(
              key: _passwordFormKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Current Password
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      hint: 'Enter your current password',
                      isVisible: _showCurrentPassword,
                      onToggleVisibility: () => setState(
                          () => _showCurrentPassword = !_showCurrentPassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Current password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // New Password
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      hint: 'At least 8 characters',
                      isVisible: _showNewPassword,
                      onToggleVisibility: () =>
                          setState(() => _showNewPassword = !_showNewPassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'New password is required';
                        }
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(v)) {
                          return 'Include at least one uppercase letter';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(v)) {
                          return 'Include at least one number';
                        }
                        if (v == _currentPasswordController.text) {
                          return 'New password must differ from current';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      hint: 'Re-enter your new password',
                      isVisible: _showConfirmPassword,
                      onToggleVisibility: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (v != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Password strength hint
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF667EEA).withOpacity(0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: Color(0xFF667EEA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Password must be at least 8 characters and include an uppercase letter and a number.',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    const Color(0xFF667EEA).withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Update password button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPasswordLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF764BA2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isPasswordLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_reset_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Update Password',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF667EEA), size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF718096),
            size: 22,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF56565)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF56565), width: 2),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF667EEA), size: 22),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF56565)),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: ['Male', 'Female'].map((gender) {
              final isSelected = _selectedGender == gender;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = gender),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)])
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      gender,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF718096),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
