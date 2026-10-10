import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/account_controller.dart';

/// ST02 — Account information.
///
/// Read-only for now: there is no `PATCH /me` yet, so no edit entry point is
/// shown. Email and phone arrive already masked from the server.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(accountControllerProvider.notifier).loadAccount();
    });
  }

  void _retry() => ref.read(accountControllerProvider.notifier).loadAccount();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountControllerProvider);
    final account = state.account;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: state.errorMessage != null
          ? _AccountErrorState(message: state.errorMessage!, onRetry: _retry)
          : account == null
          ? const _AccountLoadingState()
          : _AccountContent(account: account),
    );
  }
}

class _AccountLoadingState extends StatelessWidget {
  const _AccountLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.gold),
        SizedBox(height: 16),
        Text('Loading your account…', style: AppTypography.bodyMedium),
      ],
    ),
  );
}

class _AccountErrorState extends StatelessWidget {
  const _AccountErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.manage_accounts_outlined,
            size: 44,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 180,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _initial(String word) =>
    String.fromCharCode(word.runes.first).toUpperCase();

String _initials(String? name) {
  final words = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) return _initial(words.first);
  return _initial(words.first) + _initial(words.last);
}

class _AccountContent extends StatelessWidget {
  const _AccountContent({required this.account});

  final Map<String, dynamic> account;

  @override
  Widget build(BuildContext context) {
    final fullName = _text(account['full_name']);
    final label = _text(account['account_label']) ?? 'SportsZ athlete account';
    final email = _text(account['email_masked']);
    final phone = _text(account['phone_masked']);
    final emailVerified = account['email_verified'] == true;
    final phoneVerified = account['phone_verified'] == true;
    final rawProviders = account['linked_providers'];
    final providers = rawProviders is List
        ? rawProviders.map((item) => item.toString()).toList()
        : <String>[];

    final rows = <Widget>[
      if (email != null)
        _SignInRow(
          icon: Icons.mail_outline,
          title: 'Email',
          value: email,
          status: emailVerified ? 'Verified' : 'Not verified',
          warn: !emailVerified,
        ),
      if (phone != null)
        _SignInRow(
          icon: Icons.phone_outlined,
          title: 'Phone',
          value: phone,
          status: phoneVerified ? 'Verified' : 'Not verified',
          warn: !phoneVerified,
        ),
      if (providers.contains('google.com'))
        const _SignInRow(
          icon: Icons.public,
          title: 'Google',
          value: 'Linked account',
          status: 'Linked',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account information', style: AppTypography.h1),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your sign-in details and account identity.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    child: Row(
                      children: [
                        _Avatar(initials: _initials(fullName)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName ?? 'SportsZ athlete',
                                style: AppTypography.h4,
                              ),
                              const SizedBox(height: 2),
                              Text(label, style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIGN-IN DETAILS',
                          style: AppTypography.labelSmall.copyWith(
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No sign-in details available.',
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: AppColors.divider),
                          rows[i],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ST03 (Security) is not built yet, so this row is a
                  // non-interactive placeholder rather than a dead link.
                  const _Card(
                    child: Row(
                      children: [
                        _IconBadge(icon: Icons.verified_user_outlined),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Security', style: AppTypography.h4),
                              SizedBox(height: 2),
                              Text(
                                'Methods, sessions and devices',
                                style: AppTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Coming soon', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.lightGold,
      shape: BoxShape.circle,
    ),
    child: initials.isEmpty
        ? const Icon(Icons.person_outline, color: AppColors.deepAccent)
        : Text(
            initials,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.deepAccent,
            ),
          ),
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.lightGold,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppColors.deepAccent, size: 22),
  );
}

class _SignInRow extends StatelessWidget {
  const _SignInRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    this.warn = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String status;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        _IconBadge(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h4),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.bodyMedium),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: AppTypography.bodySmall.copyWith(
            color: warn ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
