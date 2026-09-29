import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/sportsz_logo.dart';
import '../widgets/sportsz_ui.dart';
import 'login_screen.dart';

const _bg = Color(0xFF0B0A08);
const _cardBorder = Color(0x66D4A02A);

/// Athlete Dashboard (dark). Stats / Sports ID abhi placeholder hain.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _tab = 0;

  Future<void> _logout() async {
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

  BoxDecoration _cardDeco() => BoxDecoration(
    gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1C1710), Color(0xFF0F0D09)]),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _cardBorder),
  );

  Widget _iconTile(IconData icon, {double size = 46, bool circle = false}) =>
      Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: const Color(0xFF3A2C0E),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(12),
          border: Border.all(color: const Color(0x88D4A02A)),
        ),
        child: Icon(icon, color: const Color(0xFFE8B437), size: size * 0.5),
      );

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco(),
        child: Row(children: [
          _iconTile(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.white70)),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward, size: 17, color: Colors.white70),
        ]),
      ),
    );
  }

  Widget _activity(IconData icon, String title, String sub, String asset) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 150,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF2A2010))),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF12100B), Color(0x00000000)]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _iconTile(icon, size: 42, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final sel = _tab == i;
    final c = sel ? const Color(0xFFE8B437) : Colors.white70;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: c, size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  color: c,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
          const SizedBox(height: 3),
          Container(
              height: 2,
              width: 34,
              color: sel ? const Color(0xFFE8B437) : Colors.transparent),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final name = ((user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Athlete'))
        .toUpperCase();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(children: [
              const HeroImage(asset: 'assets/images/dashboard_bg.png', height: 380),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), _bg],
                      stops: [0.5, 1],
                    ),
                  ),
                ),
              ),
            ]),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                        child: SportsZLogo(size: 18, showTagline: true)),
                    Stack(children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none,
                            color: Colors.white, size: 28),
                        onPressed: () {},
                      ),
                      Positioned(
                        right: 12,
                        top: 10,
                        child: Container(
                            height: 9,
                            width: 9,
                            decoration: const BoxDecoration(
                                color: Color(0xFFF5A623),
                                shape: BoxShape.circle)),
                      ),
                    ]),
                    IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 26),
                      onPressed: _logout,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Athlete Dashboard',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Container(
                    height: 3, width: 60, color: const Color(0xFFE8B437)),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1408),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8B437), width: 2),
                    ),
                    child: const Icon(Icons.person,
                        color: Color(0xFFE8B437), size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8C640C), Color(0xFFC99A22), Color(0xFF8C640C)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3C557)),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE8B437).withValues(alpha: 0.35),
                          blurRadius: 16)
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.badge_outlined,
                        color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Sports ID',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                          Text('SZ2025001',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.circle, size: 10, color: AppColors.success),
                        SizedBox(width: 6),
                        Text('Verified',
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E7A44),
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _stat(Icons.videocam, '12', 'Total Videos'),
                  const SizedBox(width: 10),
                  _stat(Icons.bar_chart, '8', 'Performance Records'),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _stat(Icons.verified, '3', 'Eligibility Status'),
                  const SizedBox(width: 10),
                  _stat(Icons.flag_outlined, '2', 'Active Goals'),
                ]),
                const SizedBox(height: 22),
                Row(children: [
                  const Icon(Icons.monitor_heart_outlined,
                      color: Color(0xFFE8B437), size: 28),
                  const SizedBox(width: 10),
                  const Text('Recent Activity',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const Spacer(),
                  const Text('View All',
                      style: TextStyle(color: Color(0xFFE8B437), fontSize: 14)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward,
                      color: Color(0xFFE8B437), size: 18),
                ]),
                const SizedBox(height: 12),
                _activity(Icons.videocam, 'Performance video uploaded',
                    '100m Sprint  •  2 days ago', 'assets/images/activity_run.png'),
                _activity(Icons.work, 'New job opportunity',
                    'Sports Academy  •  3 days ago', 'assets/images/activity_field.png'),
                const SizedBox(height: 6),
                const Text('Better Athletes\n  Build a Brighter Future',
                    style: TextStyle(
                        fontFamily: 'cursive',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        height: 1.3,
                        color: Color(0xFFE8B437))),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0C09),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0x55D4A02A)),
          ),
          child: Row(children: [
            _navItem(0, Icons.home_outlined, 'Home'),
            _navItem(1, Icons.bar_chart, 'Performance'),
            _navItem(2, Icons.upload_outlined, 'Upload'),
            _navItem(3, Icons.person_outline, 'Profile'),
          ]),
        ),
      ),
    );
  }
}