import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/auth_service.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import 'home_screen.dart';
import 'role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    final user = _authService.currentUser;
    if (!mounted) return;

    if (user != null) {
      final verified =
          _authService.isGoogleUser() || await _authService.isEmailVerified();
      if (!mounted) return;

      if (verified) {
        final backendData = await _authService.verifyWithBackend();
        if (!mounted) return;

        if (backendData != null) {
          _go(
            backendData['role'] == null
                ? const RoleSelectionScreen()
                : const HomeScreen(),
          );
          return;
        }
        // Backend unreachable, lekin Firebase login hai -> Home
        _go(const HomeScreen());
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
