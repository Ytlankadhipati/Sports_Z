import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/sportsz_logo.dart';
import '../../data/datasources/auth_service.dart';
import '../controllers/auth_controller.dart';
import 'role_selection_screen.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkVerification(silent: true);
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isChecking = true;
        _message = null;
      });
    }

    final verified = await _authService.isEmailVerified();
    if (!mounted) return;

    if (!verified) {
      if (!silent) {
        setState(() {
          _isChecking = false;
          _message = 'Email not verified yet. Please check your inbox.';
        });
      }
      return;
    }

    _autoCheckTimer?.cancel();
    setState(() => _isChecking = true);

    final backendData = await ref
        .read(authControllerProvider.notifier)
        .verifyWithBackend();
    if (!mounted) return;

    if (backendData == null) {
      setState(() {
        _isChecking = false;
        _message = ref.read(authControllerProvider).errorMessage ?? 'Could not verify your SportsZ account. Check your connection and retry.';
      });
      // dobara retry loop shuru karo
      _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkVerification(silent: true);
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
    );
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    final result = await _authService.resendVerificationEmail();

    setState(() {
      _isResending = false;
      _message = result ?? 'Verification email sent again!';
    });
  }

  Future<void> _backToLogin() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiLoading = ref.watch(authControllerProvider).isLoading;
    final email = _authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SportsZLogo(
                size: 28,
                taglineColor: AppColors.textSecondary,
              ),
              const SizedBox(height: 40),
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: AppColors.lightGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 46,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Click the link in your email, then tap the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _message!.contains('sent again')
                        ? AppColors.lightGold
                        : AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _message!.contains('sent again')
                          ? AppColors.gold
                          : AppColors.error,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      color: _message!.contains('sent again')
                          ? AppColors.deepAccent
                          : AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isChecking || apiLoading
                      ? null
                      : () => _checkVerification(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isChecking || apiLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "I've Verified My Email",
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _isResending ? null : _resendEmail,
                child: Text(
                  _isResending ? 'Sending...' : 'Resend Verification Email',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _backToLogin,
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
