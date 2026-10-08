import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sports_z/shared/theme/app_theme.dart';
import 'package:sports_z/shared/widgets/sz_auth_ui.dart';
import 'package:sports_z/features/auth/data/datasources/auth_service.dart';
import 'home_screen.dart';
import 'recovery_screen.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';

// ─────────────────────────────────────────────────────────────
// A04 — Email Login Screen
// Figma: M1_A04_EmailForm  |  "Sign in with email"
// ─────────────────────────────────────────────────────────────

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    HapticFeedback.lightImpact();

    final err = await _authService.loginWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
      return;
    }

    final verified = await _authService.isEmailVerified();
    if (!mounted) return;
    if (!verified) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please verify your email first.'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final backendData = await _authService.verifyWithBackend();
    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => backendData == null || backendData['role'] == null
            ? const OnboardingScreen()
            : const HomeScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SzPageHeader(
              id: 'A04',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SzSectionTitle(
                        title: 'Sign in with email',
                        subtitle: 'Access your SportsZ athlete identity.',
                      ),
                      const SzFormLabel(text: 'Email address'),
                      SzTextField(
                        controller: _emailCtrl,
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter your email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const SzFormLabel(text: 'Password'),
                      SzTextField(
                        controller: _passCtrl,
                        hint: 'Your password',
                        obscure: _obscurePass,
                        trailing: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your password';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecoveryScreen(
                                initialEmail: _emailCtrl.text.trim(),
                              ),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            textStyle: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        SzErrorCard(message: _error!),
                        const SizedBox(height: 12),
                      ],
                      Center(
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            textStyle: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                            ),
                          ),
                          child: const Text('Having trouble with your session?'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SzStickyFooter(
              child: SzGoldButton(
                label: 'Continue',
                loading: _loading,
                onPressed: _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
