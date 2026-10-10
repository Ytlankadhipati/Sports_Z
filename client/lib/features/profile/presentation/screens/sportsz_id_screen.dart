import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../controllers/profile_controller.dart';
import 'profile_edit_support.dart';

typedef SportsZIdentityLoader = Future<Map<String, dynamic>> Function();

/// I01 — the signed-in athlete's backend-issued SportsZ identity.
class SportsZIdScreen extends ConsumerStatefulWidget {
  final SportsZIdentityLoader? loadIdentity;

  const SportsZIdScreen({super.key, this.loadIdentity});

  @override
  ConsumerState<SportsZIdScreen> createState() => _SportsZIdScreenState();
}

class _SportsZIdScreenState extends ConsumerState<SportsZIdScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _identity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await (widget.loadIdentity?.call() ??
                  ref.read(profileControllerProvider.notifier).loadSportszId())
              .timeout(const Duration(seconds: 15));
      final data = responseData(response);
      final sportszId = data['sportsz_id']?.toString().trim() ?? '';
      if (sportszId.isEmpty) {
        throw const _IdentityFailure('Your SportsZ ID is not available yet.');
      }
      if (!mounted) return;
      setState(() {
        _identity = data;
        _loading = false;
      });
    } on _IdentityFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          final apiError = apiExceptionFrom(error);
          _error = apiError?.statusCode == 404
              ? 'Your SportsZ ID has not been issued yet.'
              : profileRequestError(
                  error,
                  saving: false,
                  fallback: 'Could not load your SportsZ ID. Check your connection and retry.',
                );
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('SportsZ ID'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back to profile',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: _loading
          ? const ProfileLoadingState()
          : _error != null
          ? _IdErrorState(message: _error!, onRetry: _load)
          : _identity == null
          ? _IdErrorState(
              message: 'Your SportsZ ID is not available yet.',
              onRetry: _load,
            )
          : _identityCard(_identity!),
    );
  }

  Widget _identityCard(Map<String, dynamic> data) {
    final id = data['sportsz_id'].toString();
    final name = data['full_name']?.toString().trim() ?? '';
    final sport = data['primary_sport']?.toString().trim() ?? '';
    final positions = data['positions'] is List
        ? (data['positions'] as List)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .join(' · ')
        : '';
    final level = data['level']?.toString().trim() ?? '';
    final subtitle = [
      sport,
      positions,
      level,
    ].where((value) => value.isNotEmpty).join(' · ');
    final photoUrl = data['photo_url']?.toString().trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 12.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 0.91,
                    child: _DigitalIdCard(
                      sportszId: id,
                      name: name,
                      subtitle: subtitle,
                      photoUrl: photoUrl,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'SportsZ digital sports credential. Not a government ID.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium,
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

class _DigitalIdCard extends StatelessWidget {
  final String sportszId;
  final String name;
  final String subtitle;
  final String? photoUrl;

  const _DigitalIdCard({
    required this.sportszId,
    required this.name,
    required this.subtitle,
    required this.photoUrl,
  });

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'SZ' : initials;
  }

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30000000),
          blurRadius: 28,
          offset: Offset(0, 16),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -140,
          bottom: -165,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 72),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'SZ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EB),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF32813A),
                          size: 17,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'ID issued',
                          style: TextStyle(
                            color: Color(0xFF32813A),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'SPORTSZ DIGITAL ATHLETE ID',
                style: TextStyle(
                  color: Color(0xFFE7C66F),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: photoUrl != null && photoUrl!.isNotEmpty
                          ? Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _photoFallback(),
                            )
                          : _photoFallback(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Athlete' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'SPORTSZ ID',
                style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 11),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  sportszId,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'SPORTSZ DIGITAL CREDENTIAL',
                style: TextStyle(
                  color: Color(0xFFE7C66F),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _photoFallback() => Container(
    color: AppColors.lightGold,
    alignment: Alignment.center,
    child: Text(
      _initials,
      style: const TextStyle(
        color: AppColors.deepAccent,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _IdErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _IdErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.badge_outlined,
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
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to profile'),
            style: TextButton.styleFrom(minimumSize: const Size(180, 48)),
          ),
        ],
      ),
    ),
  );
}

class _IdentityFailure implements Exception {
  final String message;
  const _IdentityFailure(this.message);
}
