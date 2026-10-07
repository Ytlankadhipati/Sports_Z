import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sports_z/shared/theme/app_theme.dart';
import 'package:sports_z/shared/widgets/sportsz_logo.dart';
import 'package:sports_z/features/auth/data/datasources/auth_service.dart';
import 'email_login_screen.dart';
import 'phone_login_screen.dart';
import 'link_accounts_screen.dart';
import 'home_screen.dart';
import 'role_selection_screen.dart';

// ─────────────────────────────────────────────────────────────
// A03 — Auth Chooser Screen
// Figma: M1_A03_AuthChooser  |  "Welcome to SportsZ"
// ─────────────────────────────────────────────────────────────

class AuthChooserScreen extends StatefulWidget {
  const AuthChooserScreen({super.key});

  @override
  State<AuthChooserScreen> createState() => _AuthChooserScreenState();
}

class _AuthChooserScreenState extends State<AuthChooserScreen> {
  bool _googleLoading = false;
  final _authService = AuthService();

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);
    final error = await _authService.signInWithGoogle();
    if (!mounted) return;
    if (error != null) {
      setState(() => _googleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final backendData = await _authService.verifyWithBackend();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (backendData == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LinkAccountsScreen()),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => backendData['role'] == null
            ? const RoleSelectionScreen()
            : const HomeScreen(),
      ),
      (_) => false,
    );
  }

  void _push(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => screen,
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Back button row
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: AppColors.textPrimary),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SportsZLogo(size: 18),
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome to SportsZ',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a secure way to continue.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _AuthOption(
                      icon: Icons.mail_outline,
                      label: 'Continue with email',
                      onTap: () => _push(const EmailLoginScreen()),
                      highlighted: true,
                    ),
                    const SizedBox(height: 10),
                    _AuthOption(
                      icon: Icons.smartphone_outlined,
                      label: 'Continue with phone',
                      onTap: () => _push(const PhoneLoginScreen()),
                    ),
                    const SizedBox(height: 10),
                    _AuthOption(
                      icon: null,
                      label: 'Continue with Google',
                      onTap: _googleLoading ? null : _handleGoogle,
                      isGoogleLoading: _googleLoading,
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'By continuing, you agree to the SportsZ Terms and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthOption extends StatefulWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool isGoogleLoading;

  const _AuthOption({
    this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.isGoogleLoading = false,
  });

  @override
  State<_AuthOption> createState() => _AuthOptionState();
}

class _AuthOptionState extends State<_AuthOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.lightGold.withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.highlighted ? AppColors.gold : AppColors.border,
            width: widget.highlighted ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            if (widget.icon != null)
              Icon(widget.icon, size: 20, color: AppColors.gold)
            else if (widget.isGoogleLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.gold),
              )
            else
              const _GoogleG(),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

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
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
