import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../data/datasources/auth_service.dart';
import '../controllers/auth_controller.dart';
import '../../../../../shared/widgets/sportsz_logo.dart';
import 'login_screen.dart';
import 'link_accounts_screen.dart';
import 'session_expired_screen.dart';
import '../../../account/presentation/screens/account_screen.dart';
import '../../../onboarding/presentation/screens/athlete_identity_screen.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/screens/my_profile_screen.dart';
import '../../../profile/presentation/screens/edit_hub_screen.dart';
import '../../../profile/presentation/screens/sportsz_id_screen.dart';

/// Athlete Dashboard (SportsZ Light Theme).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AuthService _authService = AuthService();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileControllerProvider.notifier).loadProfile();
    });
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyProfileScreen(
          onViewId: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SportsZIdScreen()),
            );
          },
          onEditProfile: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditHubScreen()),
            );
            if (mounted) {
              ref.read(profileControllerProvider.notifier).loadProfile();
            }
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // Best-effort: tell the backend to invalidate the server-side session.
    // A 3-second timeout and all exceptions are swallowed so an offline device
    // or an already-expired token never blocks the local sign-out.
    try {
      await ref
          .read(authRepositoryProvider)
          .logoutFromBackend()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Intentionally ignored — local sign-out must always succeed.
    }
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  BoxDecoration _cardDeco({bool highlight = false}) => BoxDecoration(
    color: highlight ? AppColors.lightGold : AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: highlight ? AppColors.gold : AppColors.border,
      width: highlight ? 1.4 : 1,
    ),
    boxShadow: [
      BoxShadow(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _iconTile(IconData icon, {double size = 44, bool circle = false}) =>
      Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppColors.lightGold,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: AppColors.gold, size: size * 0.5),
      );

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(),
        child: Row(
          children: [
            _iconTile(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
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

  Widget _activity(IconData icon, String title, String sub, String asset) {
    return Container(
      height: 68,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _iconTile(icon, size: 40, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, {VoidCallback? onTap}) {
    final sel = _tab == i;
    final c = sel ? AppColors.gold : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => setState(() => _tab = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                color: c,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2.5,
              width: 24,
              decoration: BoxDecoration(
                color: sel ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;
    final user = _authService.currentUser;
    final fullName = (profile?['full_name'] as String?)?.trim();
    final name = (fullName != null && fullName.isNotEmpty)
        ? fullName.toUpperCase()
        : (((user?.displayName?.isNotEmpty ?? false)
                  ? user!.displayName!
                  : (user?.email?.split('@').first ?? 'Athlete'))
              .toUpperCase());
    final sportszId = (profile?['sportsz_id'] as String?)?.trim();

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const SportsZLogo(
          size: 20,
          taglineColor: AppColors.textSecondary,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: AppColors.textPrimary,
              size: 24,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: _logout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Greeting row
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openProfile,
              child: Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.lightGold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.gold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sports ID Credential Card (Light Premium)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SportsZIdScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.lightGold, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your SportsZ ID',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (sportszId != null && sportszId.isNotEmpty)
                                ? sportszId
                                : 'SZ2025001',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Grid (2x2)
            Row(
              children: [
                _stat(Icons.videocam_outlined, '12', 'Total Videos'),
                const SizedBox(width: 10),
                _stat(Icons.bar_chart, '8', 'Performance Records'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat(Icons.verified_outlined, '3', 'Eligibility Status'),
                const SizedBox(width: 10),
                _stat(Icons.flag_outlined, '2', 'Active Goals'),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activity Section
            Row(
              children: [
                const Icon(Icons.timeline, color: AppColors.gold, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),
            _activity(
              Icons.videocam_outlined,
              'Performance video uploaded',
              '100m Sprint  •  2 days ago',
              'assets/images/activity_run.png',
            ),
            _activity(
              Icons.work_outline,
              'New scout opportunity',
              'Sports Academy  •  3 days ago',
              'assets/images/activity_field.png',
            ),
            const SizedBox(height: 16),

            // Quick Access / Development testing cards
            const Text(
              'Quick Access & Verification',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: _cardDeco(),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.lightGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Linked Accounts',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Google, Phone & Email providers',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textMuted,
                  size: 14,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LinkAccountsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: _cardDeco(),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.lightGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Athlete Onboarding (O01 / O02)',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Identity Setup, Sport & SportsZ ID Card',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textMuted,
                  size: 14,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AthleteIdentityScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // TEMP entry until M2's ST01 Settings hub exists.
            Container(
              decoration: _cardDeco(),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.lightGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.manage_accounts_outlined,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Account (ST02)',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Sign-in details and account identity',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textMuted,
                  size: 14,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: _cardDeco(),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Test Session Timeout',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Simulate expired auth token (A07)',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textMuted,
                  size: 14,
                ),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SessionExpiredScreen(
                        reason:
                            'Your session has expired. Please sign in again.',
                      ),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, 'Home'),
            _navItem(1, Icons.bar_chart, 'Performance'),
            _navItem(2, Icons.upload_outlined, 'Upload'),
            _navItem(3, Icons.person_outline, 'Profile', onTap: _openProfile),
          ],
        ),
      ),
    );
  }
}
