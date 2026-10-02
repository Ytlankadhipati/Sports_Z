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
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Linked Accounts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text(
              'Manage your sign-in methods. Linking multiple accounts ensures you never lose access to your SportsZ profile.',
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.65), height: 1.4),
            ),
            const SizedBox(height: 24),
            _buildProviderCard(
              title: 'Google',
              subtitle: _authService.currentUser?.email ?? 'Connect your Google account',
              icon: Icons.g_mobiledata,
              iconColor: Colors.redAccent,
              isLinked: _isLinked('google.com'),
              onLink: _handleLinkGoogle,
            ),
            const SizedBox(height: 14),
            _buildProviderCard(
              title: 'Phone Number',
              subtitle: _authService.currentUser?.phoneNumber ?? 'Link phone for SMS OTP verification',
              icon: Icons.phone_android,
              iconColor: Colors.blueAccent,
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
              iconColor: AppColors.gold,
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
        color: const Color(0xFF1B1A17),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLinked ? AppColors.gold.withOpacity(0.4) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLinked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'LINKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
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
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                elevation: 0,
              ),
              child: const Text('Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            )
          else if (isLinked)
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
        ],
      ),
    );
  }
}
