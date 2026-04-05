import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:lottie/lottie.dart';

// Required Firebase Imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// Import local files
import 'authentication.dart';
import 'calibration_store.dart';
import 'ridge_trainer.dart';
import 'history_screen.dart';
import 'trends_screen.dart';
import 'finger_guide_screen.dart';
import 'export_data_screen.dart';
import 'reminder_screen.dart';
import 'notification_service.dart';

// Import extracted screens
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/measurement/hr/hr_measurement_screen.dart';
import 'screens/measurement/hr/hr_result_screen.dart';
import 'screens/measurement/bp/bp_measurement_screen.dart';
import 'screens/measurement/bp/bp_result_screen.dart';
import 'screens/measurement/bp/bp_logging_screen.dart';

// Import extracted widgets
import 'widgets/build_header_cell.dart';
import 'widgets/finger_placement_guide.dart';
import 'widgets/bp_category_widgets.dart';

// Import extracted utilities
import 'utils/firestore_utils.dart';
import 'utils/camera_utils.dart';

FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.instance.initialize();

  final cameras = await availableCameras();
  runApp(CardioCareApp(cameras: cameras));
}

class CardioCareApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const CardioCareApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardioCare',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Inter',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // App starts with the Splash Screen to check user state
      home: SplashScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

// SplashScreen, WelcomeScreen, HomeScreen, DashboardScreen, ProfileScreen, EditProfileScreen, and ForgotPasswordScreen
// have been extracted to separate files in the screens/ directory

// HRMeasurementScreen, HRResultScreen, BPMeasurementScreen, BPResultScreen, and BPLoggingScreen
// have been extracted to separate files in the screens/measurement/ directory

// ============================================================================
// COLLAPSIBLE CATEGORY SECTION WIDGET
// ============================================================================

// CollapsibleCategorySection and BPCategoryAccordion have been extracted to widgets/bp_category_widgets.dart

// EditProfileScreen has been extracted to screens/profile/edit_profile_screen.dart

// HRMeasurementScreen has been extracted to screens/measurement/hr/hr_measurement_screen.dart

// ProfileScreen has been extracted to screens/profile/profile_screen.dart

// BPMeasurementScreen has been extracted to screens/measurement/bp/bp_measurement_screen.dart

// HR Result Screen has been extracted to screens/measurement/hr/hr_result_screen.dart

// BP Measurement Screen has been extracted to screens/measurement/bp/bp_measurement_screen.dart

// BP Result Screen has been extracted to screens/measurement/bp/bp_result_screen.dart

// BP Logging Screen has been extracted to screens/measurement/bp/bp_logging_screen.dart

// ProfileScreen has been extracted to screens/profile/profile_screen.dart

// BPMeasurementScreen has been extracted to screens/measurement/bp/bp_measurement_screen.dart

// EditProfileScreen has been extracted to screens/profile/edit_profile_screen.dart

// CameraListExtension, saveReadingToFirestore, BuildHeaderCell, ForgotPasswordScreen, and FingerPlacementGuide
// have been extracted to separate files in utils/ and widgets/ directories
