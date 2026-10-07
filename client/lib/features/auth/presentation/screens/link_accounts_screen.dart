import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';
import '../../data/datasources/auth_service.dart';

class LinkAccountsScreen extends StatefulWidget {
  const LinkAccountsScreen({super.key});

  @override
  State<LinkAccountsScreen> createState() => _LinkAccountsScreenState();
}

class _LinkAccountsScreenState extends State<LinkAccountsScreen> {
  final AuthService _authService = AuthService();
  late List<String> _linkedProviders;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshProviders();
  }

  void _refreshProviders() {
    setState(() {
      _linkedProviders = _authService.getLinkedProviders();
    });
  }

  bool _isLinked(String providerId) => _linkedProviders.contains(providerId);

  Future<void> _handleLinkGoogle() async {
    setState(() => _isLoading = true);
    final error = await _authService.linkWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      _refreshProviders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google account linked successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Linked Accounts',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            const Text(
              'Manage your sign-in methods. Linking multiple accounts ensures you never lose access to your SportsZ profile.',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildProviderCard(
              title: 'Google',
              subtitle: _authService.currentUser?.email ?? 'Connect your Google account',
              icon: Icons.g_mobiledata,
              iconColor: const Color(0xFFEA4335),
              isLinked: _isLinked('google.com'),
              onLink: _handleLinkGoogle,
            ),
            const SizedBox(height: 14),
            _buildProviderCard(
              title: 'Phone Number',
              subtitle: _authService.currentUser?.phoneNumber ?? 'Link phone for SMS OTP verification',
              icon: Icons.phone_android,
              iconColor: AppColors.gold,
              isLinked: _isLinked('phone'),
              onLink: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone linking is handled via OTP verification.')),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildProviderCard(
              title: 'Email & Password',
              subtitle: _authService.currentUser?.email ?? 'Standard email login',
              icon: Icons.email_outlined,
              iconColor: AppColors.deepAccent,
              isLinked: _isLinked('password'),
              onLink: null, // Password provider is setup at registration
            ),
            if (_isLoading) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isLinked,
    VoidCallback? onLink,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLinked ? AppColors.gold : AppColors.border,
          width: isLinked ? 1.4 : 1,
        ),
        boxShadow: isLinked
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isLinked ? AppColors.lightGold : AppColors.secondaryBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLinked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: const Text(
                          'LINKED',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isLinked && onLink != null)
            ElevatedButton(
              onPressed: _isLoading ? null : onLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                elevation: 0,
              ),
              child: const Text(
                'Link',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (isLinked)
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}
