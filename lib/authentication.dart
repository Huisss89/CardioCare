import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'main.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/forgot_password_screen.dart';

// ═══════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
const _kPurple1 = Color(0xFF667EEA);
const _kPurple2 = Color(0xFF764BA2);
const _kBgLight = Color(0xFFF8F7FF); // very faint lavender white
const _kCardBg = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE8E4F4);
const _kTextDark = Color(0xFF1E1B2E);
const _kTextMid = Color(0xFF6B6880);
const _kTextSub = Color(0xFFACA9BE);

// ═══════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const LoginScreen({super.key, required this.cameras});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── All original controllers & state ────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Entrance animation ───────────────────────────────────────
  late final AnimationController _enterCtrl;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── All original logic — unchanged ──────────────────────────
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user != null) {
        final userEmail = userCredential.user!.email!;
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserEmail', userEmail);
        await prefs.setBool('isLoggedIn', true);
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          print('[LOGIN] Firestore data: $userData');
          await prefs.setString(
              '${userEmail}_userName', userData['name']?.toString() ?? 'User');
          await prefs.setString('${userEmail}_userEmail', userEmail);
          final age = userData['age'];
          final weight = userData['weight'];
          final height = userData['height'];
          await prefs.setString(
              '${userEmail}_userAge', age != null ? age.toString() : '');
          await prefs.setString('${userEmail}_userWeight',
              weight != null ? weight.toString() : '');
          await prefs.setString('${userEmail}_userHeight',
              height != null ? height.toString() : '');
          await prefs.setString(
              '${userEmail}_userGender', userData['gender']?.toString() ?? '');
          print(
              '[LOGIN] Saved to prefs: age=$age, weight=$weight, height=$height');
        } else {
          print('[LOGIN] ERROR: User document does not exist in Firestore!');
        }
        await FirebaseAnalytics.instance.logEvent(
          name: "login_success",
          parameters: {"user_id": userCredential.user!.uid},
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome Back, $userEmail!')),
        );
        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomeScreen(cameras: widget.cameras)));
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "An unknown authentication error occurred.";
      if (e.code == 'user-not-found')
        errorMessage = 'No user found for that email.';
      else if (e.code == 'wrong-password')
        errorMessage = 'Wrong password provided.';
      else if (e.code == 'invalid-email')
        errorMessage = 'The email address is not valid.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
      await FirebaseAnalytics.instance.logEvent(
        name: "login_failure",
        parameters: {"email": _emailController.text, "error_code": e.code},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'An unexpected error occurred. Please check your internet is connected and try again.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user != null) {
        final userEmail = user.email!;
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserEmail', userEmail);
        await prefs.setBool('isLoggedIn', true);
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? 'User',
            'email': userEmail,
            'age': 0,
            'gender': '',
            'weight': 0.0,
            'height': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
            'provider': 'google',
          });
          await prefs.setString(
              '${userEmail}_userName', user.displayName ?? 'User');
          await prefs.setString('${userEmail}_userEmail', userEmail);
          await prefs.setString('${userEmail}_userAge', '');
          await prefs.setString('${userEmail}_userWeight', '');
          await prefs.setString('${userEmail}_userHeight', '');
          await prefs.setString('${userEmail}_userGender', '');
          await prefs.setStringList('${userEmail}_hrHistory', []);
          await prefs.setStringList('${userEmail}_bpHistory', []);
        } else {
          final userData = userDoc.data()!;
          final age = userData['age'];
          final weight = userData['weight'];
          final height = userData['height'];
          await prefs.setString(
              '${userEmail}_userName', userData['name']?.toString() ?? 'User');
          await prefs.setString('${userEmail}_userEmail', userEmail);
          await prefs.setString(
              '${userEmail}_userAge', age != null ? age.toString() : '');
          await prefs.setString('${userEmail}_userWeight',
              weight != null ? weight.toString() : '');
          await prefs.setString('${userEmail}_userHeight',
              height != null ? height.toString() : '');
          await prefs.setString(
              '${userEmail}_userGender', userData['gender']?.toString() ?? '');
        }
        await FirebaseAnalytics.instance.logEvent(
          name: "login_success",
          parameters: {"user_id": user.uid, "method": "google"},
        );
        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomeScreen(cameras: widget.cameras)));
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Google Sign-In failed. Please try again.')));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      body: Stack(
        children: [
          // ── Decorative background orbs ─────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: _Orb(
                size: 260,
                color1: _kPurple1.withOpacity(0.18),
                color2: _kPurple2.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _Orb(
                size: 300,
                color1: _kPurple2.withOpacity(0.10),
                color2: _kPurple1.withOpacity(0.06)),
          ),

          // ── Main content ───────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _enterFade,
              child: SlideTransition(
                position: _enterSlide,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),

                      // ── Logo + headline ──────────────────
                      _buildHero(),

                      const SizedBox(height: 40),

                      // ── Form card ────────────────────────
                      _buildFormCard(),

                      const SizedBox(height: 20),

                      // ── Sign up link ──────────────────────
                      _buildSignUpRow(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero section ─────────────────────────────────────────────
  Widget _buildHero() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          const Text('Hi There 👋',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                  height: 1.1,
                  letterSpacing: -0.8)),
          const SizedBox(height: 8),
          const Text('Sign in to continue your health journey',
              style: TextStyle(fontSize: 15.5, color: _kTextMid, height: 1.4)),
        ],
      );

  // ── Form card ────────────────────────────────────────────────
  Widget _buildFormCard() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kBorder, width: 1),
          boxShadow: [
            BoxShadow(
                color: _kPurple1.withOpacity(0.06),
                blurRadius: 40,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Column(children: [
          // Email field
          _buildInputField(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // Password field
          _buildPasswordField(),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen())),
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      color: _kPurple1,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5)),
            ),
          ),

          const SizedBox(height: 6),

          // Sign In button
          _buildSignInButton(),

          const SizedBox(height: 22),

          // ── Divider ──────────────────────────────────────
          _buildDivider(),

          const SizedBox(height: 18),

          // ── Google button ─────────────────────────────
          _buildGoogleButton(),
        ]),
      );

  // ── Input field ──────────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: _kBgLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
              color: _kTextDark, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: _kTextSub, fontSize: 14),
            prefixIcon: Icon(icon, color: _kPurple1, size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      );

  // ── Password field ───────────────────────────────────────────
  Widget _buildPasswordField() => Container(
        decoration: BoxDecoration(
          color: _kBgLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(
              color: _kTextDark, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: _kTextSub, fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: _kPurple1, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _kTextSub,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      );

  // ── Sign In button ───────────────────────────────────────────
  Widget _buildSignInButton() => GestureDetector(
        onTap: (_isLoading || _isGoogleLoading) ? null : _login,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          decoration: BoxDecoration(
            gradient: (_isLoading || _isGoogleLoading)
                ? const LinearGradient(
                    colors: [Color(0xFFB0AFCB), Color(0xFFB0AFCB)])
                : const LinearGradient(
                    colors: [_kPurple1, _kPurple2],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_isLoading || _isGoogleLoading)
                ? []
                : [
                    BoxShadow(
                        color: _kPurple1.withOpacity(0.38),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Sign In',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
          ),
        ),
      );

  // ── OR divider ───────────────────────────────────────────────
  Widget _buildDivider() => Row(children: [
        Expanded(child: Container(height: 1, color: _kBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or continue with',
              style: TextStyle(
                  color: _kTextSub,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2)),
        ),
        Expanded(child: Container(height: 1, color: _kBorder)),
      ]);

  // ── Google button ────────────────────────────────────────────
  Widget _buildGoogleButton() => GestureDetector(
        onTap: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (_isLoading || _isGoogleLoading) ? _kBorder : _kBorder,
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGoogleLoading)
                const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: _kPurple1, strokeWidth: 2.5))
              else ...[
                // Google logo in a tiny circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _kBorder),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06), blurRadius: 6)
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/images/google-icon-logo.png',
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Sign in with Google',
                    style: TextStyle(
                        color: _kTextDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1)),
              ],
            ],
          ),
        ),
      );

  // ── Sign up row ──────────────────────────────────────────────
  Widget _buildSignUpRow() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Don't have an account? ",
              style: TextStyle(color: _kTextMid, fontSize: 14)),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        SignUpScreen(cameras: widget.cameras))),
            child: const Text('Sign up',
                style: TextStyle(
                    color: _kPurple1,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════
// BACKGROUND ORB WIDGET
// ═══════════════════════════════════════════════════════════════
class _Orb extends StatelessWidget {
  final double size;
  final Color color1, color2;
  const _Orb({required this.size, required this.color1, required this.color2});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              RadialGradient(colors: [color1, color2, Colors.transparent]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
// SIGN UP SCREEN — unchanged from original
// ═══════════════════════════════════════════════════════════════
class SignUpScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const SignUpScreen({super.key, required this.cameras});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  String _gender = 'Male';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  bool _validateInput() {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text);
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        name.isEmpty ||
        _ageController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _heightController.text.isEmpty) {
      _showErrorSnackbar('Please fill all fields.');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackbar('Passwords do not match!');
      return false;
    }
    final nameRegExp = RegExp(r"^[a-zA-Z\s'-]+$");
    if (!nameRegExp.hasMatch(name) || name.length < 2) {
      _showErrorSnackbar('Full Name must contain only letters and spaces.');
      return false;
    }
    if (age == null || age < 5 || age > 100) {
      _showErrorSnackbar('Please enter a realistic age between 5 and 100.');
      return false;
    }
    if (weight == null || weight < 20.0 || weight > 250.0) {
      _showErrorSnackbar(
          'Please enter a realistic weight between 20 to 250 kg.');
      return false;
    }
    if (height == null || height < 50.0 || height > 250.0) {
      _showErrorSnackbar(
          'Please enter a realistic height between 50 to 250 cm.');
      return false;
    }
    return true;
  }

  Future<void> _signUp() async {
    if (!_validateInput()) return;
    setState(() => _isLoading = true);
    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;
      final userEmail = _emailController.text.trim();
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': userEmail,
          'age': int.tryParse(_ageController.text) ?? 0,
          'gender': _gender,
          'weight': double.tryParse(_weightController.text) ?? 0.0,
          'height': double.tryParse(_heightController.text) ?? 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedInUserEmail', userEmail);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString(
            '${userEmail}_userName', _nameController.text.trim());
        await prefs.setString('${userEmail}_userAge',
            (int.tryParse(_ageController.text) ?? 0).toString());
        await prefs.setString('${userEmail}_userGender', _gender);
        await prefs.setString('${userEmail}_userWeight',
            (double.tryParse(_weightController.text)?.round() ?? 0).toString());
        await prefs.setString('${userEmail}_userHeight',
            (double.tryParse(_heightController.text)?.round() ?? 0).toString());
        await prefs.setStringList('${userEmail}_hrHistory', []);
        await prefs.setStringList('${userEmail}_bpHistory', []);
        await FirebaseAnalytics.instance.logEvent(
          name: "signup_success",
          parameters: {
            "user_id": user.uid,
            "age": _ageController.text,
            "gender": _gender,
            "weight": _weightController.text,
            "height": _heightController.text,
          },
        );
        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomeScreen(cameras: widget.cameras)));
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          "A network error occurred. Please try again with stable network connection.";
      if (e.code == 'weak-password')
        errorMessage = 'The password provided is too weak.';
      else if (e.code == 'email-already-in-use')
        errorMessage = 'The account already exists for that email.';
      else if (e.code == 'invalid-email')
        errorMessage = 'The email address is not valid.';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      await FirebaseAnalytics.instance.logEvent(
        name: "signup_failure",
        parameters: {"email": _emailController.text, "error_code": e.code},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An error occurred during sign up.'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create Account',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748))),
              const SizedBox(height: 8),
              const Text('Sign up to get started',
                  style: TextStyle(fontSize: 16, color: Color(0xFF718096))),
              const SizedBox(height: 40),
              _buildTextField(_nameController, 'Full Name',
                  Icons.person_outline, TextInputType.text),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email', Icons.email_outlined,
                  TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_ageController, 'Age', Icons.cake_outlined,
                  TextInputType.number),
              const SizedBox(height: 16),
              _buildGenderDropdown(),
              const SizedBox(height: 16),
              _buildTextField(_weightController, 'Weight',
                  Icons.fitness_center_outlined, TextInputType.number, 'kg'),
              const SizedBox(height: 16),
              _buildTextField(_heightController, 'Height',
                  Icons.height_outlined, TextInputType.number, 'cm'),
              const SizedBox(height: 16),
              _buildPasswordTextField(),
              const SizedBox(height: 16),
              _buildConfirmPasswordTextField(),
              const SizedBox(height: 32),
              _buildSignUpButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      [TextInputType? keyboardType, String? suffixText]) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF718096)),
          prefixIcon: Icon(icon, color: const Color(0xFF667EEA)),
          suffixText: suffixText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _gender,
        decoration: const InputDecoration(
          labelText: 'Gender',
          prefixIcon: Icon(Icons.people_outline, color: Color(0xFF667EEA)),
          border: InputBorder.none,
        ),
        items: ['Male', 'Female']
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (value) => setState(() => _gender = value!),
      ),
    );
  }

  Widget _buildPasswordTextField() {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: const TextStyle(color: Color(0xFF718096)),
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF667EEA)),
          suffixIcon: IconButton(
            icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF718096)),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordTextField() {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          labelStyle: const TextStyle(color: Color(0xFF718096)),
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF667EEA)),
          suffixIcon: IconButton(
            icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: const Color(0xFF718096)),
            onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 58),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3))
            : const Text('Sign Up',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
      ),
    );
  }
}
