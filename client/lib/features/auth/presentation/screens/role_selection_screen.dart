import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../../../../../shared/widgets/sportsz_logo.dart';
import '../../../../../shared/widgets/sportsz_ui.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../../../onboarding/presentation/screens/athlete_identity_screen.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole = 'athlete'; // design mein Athlete pehle se selected
  bool _isLoading = false;
  String? _errorMessage;

  void _goBack() {
    if (!mounted || _isLoading || ref.read(authControllerProvider).isLoading) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  final List<Map<String, dynamic>> _roles = [
    {
      'title': 'Athlete',
      'desc': 'Track your performance, build\nyour Sports ID and grow.',
      'icon': Icons.directions_run,
      'value': 'athlete',
    },
    {
      'title': 'Coach',
      'desc': 'Discover and evaluate athletes,\nmanage your team.',
      'icon': Icons.sports,
      'value': 'coach',
    },
    {
      'title': 'Institute',
      'desc': 'Manage institute activities\nand talent.',
      'icon': Icons.account_balance,
      'value': 'institute',
    },
    {
      'title': 'Recruiter',
      'desc': 'Find and hire top talent for\nyour team.',
      'icon': Icons.person_search,
      'value': 'recruiter',
    },
  ];

  Future<void> _handleContinue() async {
    if (_selectedRole == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await ref
        .read(authControllerProvider.notifier)
        .selectRole(_selectedRole!);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (data == null) {
      setState(
        () => _errorMessage =
            ref.read(authControllerProvider).errorMessage ??
            'Could not save your role. Check your connection and retry.',
      );
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Role set successfully!')));
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => _selectedRole == 'athlete'
            ? const AthleteIdentityScreen()
            : const HomeScreen(),
      ),
      (route) => false,
    );
  }

  Widget _card(Map<String, dynamic> role) {
    final selected = _selectedRole == role['value'];
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role['value']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightGold : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : AppColors.lightGold,
                shape: BoxShape.circle,
              ),
              child: Icon(
                role['icon'],
                size: 26,
                color: selected ? Colors.white : AppColors.gold,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role['title'],
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.deepAccent
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role['desc'],
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 22,
              width: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        height: 10,
                        width: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiState = ref.watch(authControllerProvider);
    final loading = _isLoading || apiState.isLoading;
    final h = MediaQuery.of(context).size.height;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HeroImage(asset: 'assets/images/role_bg.png', height: 340),
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 270,
                    child: SafeArea(
                      bottom: false,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 8,
                            left: 8,
                            child: IconButton(
                              tooltip: 'Back to sign in',
                              onPressed: _goBack,
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 16,
                            left: 58,
                            child: SportsZLogo(size: 24, showTagline: true),
                          ),
                          Positioned(
                            top: 12,
                            right: 8,
                            child: TextButton(
                              onPressed: loading ? null : _handleContinue,
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
                            top: 70,
                            right: 24,
                            child: Transform.rotate(
                              angle: -0.2,
                              child: const Text(
                                'Lead\nSupport\nBuild',
                                style: TextStyle(
                                  fontFamily: 'cursive',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 22,
                                  height: 1.1,
                                  color: kLogoGold,
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
                                      TextSpan(text: 'Select '),
                                      TextSpan(
                                        text: 'Your Role',
                                        style: TextStyle(color: kLogoGold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Choose your role to get started\nwith the right experience.',
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
                    minHeight: h - 250,
                    child: Column(
                      children: [
                        ..._roles.map(_card),
                        if (_errorMessage != null ||
                            apiState.errorMessage != null) ...[
                          Text(
                            _errorMessage ?? apiState.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 4),
                        GoldButton(
                          label: 'Continue',
                          loading: loading,
                          onPressed: _selectedRole == null
                              ? null
                              : _handleContinue,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
