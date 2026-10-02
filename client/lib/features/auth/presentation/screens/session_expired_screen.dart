import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/sportsz_logo.dart';
import '../../data/datasources/auth_service.dart';
import 'login_screen.dart';

class SessionExpiredScreen extends StatefulWidget {
  final String? reason;
  const SessionExpiredScreen({super.key, this.reason});

  @override
  State<SessionExpiredScreen> createState() => _SessionExpiredScreenState();
}

class _SessionExpiredScreenState extends State<SessionExpiredScreen> {
  final AuthService _authService = AuthService();
  bool _isLoggingOut = false;

  Future<void> _handleRelogin() async {
    setState(() => _isLoggingOut = true);
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Cannot go back to authenticated screens
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const SportsZLogo(size: 28),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withOpacity(0.12),
                    border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(
                    Icons.lock_clock_outlined,
                    color: Colors.amber,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Session Expired',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.reason ??
                      'For your security, your session has timed out or your account was logged in from another device. Please sign in again to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoggingOut ? null : _handleRelogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoggingOut
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                          )
                        : const Text(
                            'Sign In Again',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
