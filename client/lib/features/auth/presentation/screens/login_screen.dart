import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../data/datasources/auth_service.dart';
import '../controllers/auth_controller.dart';
import '../../../../../shared/widgets/sportsz_logo.dart';
import '../../../../../shared/widgets/sportsz_ui.dart';
import 'signup_screen.dart';
import 'role_selection_screen.dart';
import 'email_verification_screen.dart';
import 'home_screen.dart';
import 'phone_login_screen.dart';
import 'recovery_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _goToRoleOrHome(Map<String, dynamic>? backendData) async {
    if (!mounted) return;
    if (backendData == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = ref.read(authControllerProvider).errorMessage ?? 'Could not verify your SportsZ account. Check your connection and retry.';
      });
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => backendData['role'] == null
            ? const RoleSelectionScreen()
            : const HomeScreen(),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = result;
      });
      return;
    }

    bool verified;
    try {
      verified = await _authService.isEmailVerified().timeout(
        const Duration(seconds: 30),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not check your email verification. Check your connection and retry.';
      });
      return;
    }
    if (!mounted) return;
    if (!verified) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const EmailVerificationScreen(),
        ),
      );
      return;
    }

    final backendData = await ref
        .read(authControllerProvider.notifier)
        .verifyWithBackend();
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _goToRoleOrHome(backendData);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authService.signInWithGoogle();
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = result;
      });
      return;
    }
    final backendData = await ref
        .read(authControllerProvider.notifier)
        .verifyWithBackend();
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _goToRoleOrHome(backendData);
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _iconBox(IconData icon) => Padding(
    padding: const EdgeInsets.all(8),
    child: Container(
      width: 38,
      decoration: const BoxDecoration(
        color: AppColors.lightGold,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: AppColors.gold),
    ),
  );

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        color: AppColors.textMuted,
        fontSize: 14,
      ),
      prefixIcon: _iconBox(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: b(AppColors.border),
      enabledBorder: b(AppColors.border),
      focusedBorder: b(AppColors.gold),
      errorBorder: b(AppColors.error),
      focusedErrorBorder: b(AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep this screen's controls tied to its own login attempt. A stale
    // verification started by Splash must not leave the sign-in button locked.
    final loading = _isLoading;
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HeroImage(asset: 'assets/images/login_bg.png', height: 400),
          ),
          SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(
                    height: 330,
                    child: SafeArea(
                      bottom: false,
                      child: Stack(
                        children: [
                          const Positioned(
                            top: 16,
                            left: 22,
                            child: SportsZLogo(size: 24, showTagline: true),
                          ),
                          Positioned(
                            top: 12,
                            right: 8,
                            child: TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 22,
                            bottom: 44,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    children: [
                                      TextSpan(text: 'Welcome '),
                                      TextSpan(
                                        text: 'Back',
                                        style: TextStyle(color: kLogoGold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Login to continue your journey\nand achieve your goals.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  WaveSheet(
                    minHeight: h - 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Email or Mobile Number'),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _dec(
                            'Enter your email or mobile number',
                            Icons.mail_outline,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!v.contains('@')) {
                              return 'Mobile se login ke liye "Continue with Phone" use karo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _label('Password'),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _dec(
                            'Enter your password',
                            Icons.lock,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.muted,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecoveryScreen(
                                    initialEmail: _emailController.text.trim(),
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        GoldButton(
                          label: 'Login',
                          loading: loading,
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'or',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: loading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: const _GoogleG(),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PhoneLoginScreen(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: const Icon(
                            Icons.smartphone,
                            color: AppColors.gold,
                            size: 22,
                          ),
                          label: const Text(
                            'Continue with Phone',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Don't have an account?  ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.muted,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: AppColors.gold, size: 26),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BIGGER DREAMS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                                Text(
                                  'Stronger You',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 3),
                                SizedBox(
                                  width: 74,
                                  child: Divider(
                                    color: AppColors.gold,
                                    thickness: 2,
                                    height: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multicolor Google "G" (asset ki zaroorat nahi).
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const SweepGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
          Color(0xFF4285F4),
        ],
        stops: [0.0, 0.3, 0.5, 0.75, 1.0],
      ).createShader(r),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
