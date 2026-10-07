import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/auth_service.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import 'home_screen.dart';
import 'role_selection_screen.dart';
import 'session_expired_screen.dart';
import '../../../onboarding/presentation/screens/athlete_identity_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _go(Widget screen) {
    if (_navigationScheduled) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _checkLoginStatus() async {
    try {
      await _resolveLoginStatus().timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!mounted) return;
      _go(
        const SessionExpiredScreen(
          reason: 'We could not finish loading your account. Check your connection and sign in again.',
        ),
      );
    }
  }

  Future<void> _resolveLoginStatus() async {
    final user = _authService.currentUser;
    if (!mounted) return;

    if (user != null) {
      final verified =
          _authService.isGoogleUser() ||
          user.emailVerified ||
          await _authService.isEmailVerified();
      if (!mounted) return;

      if (verified) {
        final backendData = await _authService.verifyWithBackend();
        if (!mounted) return;

        if (backendData == null) {
          _go(
            const SessionExpiredScreen(
              reason: 'We could not verify your session. Please try signing in again.',
            ),
          );
          return;
        }

        if (backendData['role'] == null) {
          _go(const RoleSelectionScreen());
        } else if (backendData['role'] == 'athlete') {
          final profileResponse = await _authService.authorizedGet(
            '/me/profile/athlete',
          );
          if (!mounted) return;
          final body = jsonDecode(profileResponse.body);
          final profile =
              profileResponse.statusCode == 200 &&
                  body is Map<String, dynamic> &&
                  body['data'] is Map<String, dynamic>
              ? body['data'] as Map<String, dynamic>
              : null;
          final sports = profile?['sports'];
          final complete =
              profile != null &&
              profile['full_name'] != null &&
              profile['date_of_birth'] != null &&
              profile['gender'] != null &&
              sports is List &&
              sports.isNotEmpty &&
              profile['bio'] != null &&
              profile['physical'] != null &&
              profile['privacy'] != null &&
              profile['sportsz_id'] != null;
          _go(complete ? const HomeScreen() : const AthleteIdentityScreen());
        } else {
          _go(const HomeScreen());
        }
        return;
      }
    }

    _go(const OnboardingScreen());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF130600),
        body: SizedBox.expand(
          child: Image.asset('assets/images/splash_bg.jpg', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
