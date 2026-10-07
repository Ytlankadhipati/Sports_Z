import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sports_z/shared/theme/app_theme.dart';
import 'package:sports_z/shared/widgets/sportsz_logo.dart';
import 'auth_chooser_screen.dart';

// ─────────────────────────────────────────────────────────────
// A02 — Welcome Screen
// Figma: M1_A02_Welcome  |  Credential card art + CTA
// ─────────────────────────────────────────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _cardController;
  late final AnimationController _fadeController;
  late final Animation<double> _cardFloat;
  late final Animation<double> _pageIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pageIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _cardFloat = CurvedAnimation(
        parent: _cardController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _cardController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _goToAuth() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const AuthChooserScreen(),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.lightGold,
        body: FadeTransition(
          opacity: _pageIn,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SportsZLogo(size: 18),
                      TextButton(
                        onPressed: _goToAuth,
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            color: AppColors.deepAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Credential card art ──────────────────────────
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SizedBox(
                      width: 260,
                      height: 160,
                      child: AnimatedBuilder(
                        animation: _cardFloat,
                        builder: (_, __) {
                          final t = _cardFloat.value;
                          return Stack(
                            children: [
                              // Back card (rotated)
                              Positioned(
                                top: 4 - t * 4,
                                left: 20 + t * 4,
                                right: 0,
                                child: Transform.rotate(
                                  angle: 0.14,
                                  child: Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8D7AA),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                              // Front card (dark)
                              Positioned.fill(
                                top: 10 + t * 6,
                                left: 0,
                                right: 18,
                                child: Transform.rotate(
                                  angle: -0.09,
                                  child: _CredentialCard(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ── Bottom section ───────────────────────────────
                Expanded(
                  flex: 6,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(0),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overline
                          Text(
                            'BUILT FOR SERIOUS ATHLETES',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.deepAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Headline
                          const Text(
                            'Your sport deserves a trusted identity.',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.6,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Sub
                          const Text(
                            'Build your professional athlete profile, organize your experience and carry a SportsZ digital credential.',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Primary CTA
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _goToAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Get started'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Secondary CTA
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              onPressed: _goToAuth,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.gold,
                                textStyle: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('I already have an account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepAccent.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gold diagonal accent
          Positioned(
            right: -12,
            top: -8,
            child: Transform.rotate(
              angle: 0.42,
              child: Container(
                width: 16,
                height: 120,
                color: AppColors.gold,
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini logo
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'SZ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Card label
              Text(
                'ATHLETE CREDENTIAL',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: AppColors.gold.withValues(alpha: 0.8),
                  fontSize: 7,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'RAVI KUMAR',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'SZ-4K7M-91Q2-7',
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              // Verified badge
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Verified',
                    style: TextStyle(
                      color: Color(0xFF91D096),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
