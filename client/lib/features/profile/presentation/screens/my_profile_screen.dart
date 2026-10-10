import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../controllers/profile_controller.dart';
import 'sportsz_id_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/sportsz_logo.dart';

// ─────────────────────────────────────────────────────────────
// P01 — My Profile Screen
// Owner: M1 | API: GET /me/profile/athlete
//
// P01 is a READ-ORIENTED overview of the athlete's OWN profile.
// Detailed editing / workflows live on their own screens; P01 only
// shows summaries and forwards taps through the callbacks below.
// ─────────────────────────────────────────────────────────────

// Semantic colours not guaranteed to exist in AppColors.
const Color _kSuccess = Color(0xFF2E7D32);
const Color _kSuccessBg = Color(0xFFE8F5E9);
const Color _kSuccessBorder = Color(0xFF81C784);

const double _kHPad = 16;
const double _kCoverHeight = 176;
const double _kAvatarSize = 96;
const double _kAvatarOverlap = 48;

// ───────────────────────── Data models ─────────────────────────

/// TODO(M1-backend): Map to the approved verification field once confirmed.
enum ProfileVerificationStatus { unverified, pending, verified }

class ExperienceItem {
  final String title;
  final String organization;
  final String duration;
  final String? description;

  const ExperienceItem({
    required this.title,
    required this.organization,
    required this.duration,
    this.description,
  });
}

/// Sport-agnostic performance stat (label/value are display strings).
/// TODO(M5-backend): Map from the existing M5 performance summary API.
class PerformanceStat {
  final String label;
  final String value;
  const PerformanceStat({required this.label, required this.value});
}

class PerformanceSummary {
  final int? matchesCount;
  final List<PerformanceStat> stats;
  const PerformanceSummary({this.matchesCount, this.stats = const []});
}

/// TODO(M5-backend): Map from the existing achievements API (P12/P13 data).
class AchievementItem {
  final String title;
  final String? emoji;
  final String? subtitle;
  const AchievementItem({required this.title, this.emoji, this.subtitle});
}

/// TODO(M1-backend): Map from the Media Gallery (P17) recent-media data.
class MediaPreviewItem {
  final String? thumbnailUrl;
  final bool isVideo;
  const MediaPreviewItem({this.thumbnailUrl, this.isVideo = false});
}

class AthleteProfileData {
  final String name;
  final String sport;
  final String role;
  final String level;
  final String ageCategory;
  final String gender;
  final String? city;
  final String? bio;
  final String? sportszId;
  final String? avatarEmoji;
  final String? photoUrl;

  // TODO(M1-backend): Map to the approved backend profile/media field once confirmed.
  final String? coverPhotoUrl;

  final double? heightCm;
  final double? weightKg;
  final String? dominantHand;
  final List<ExperienceItem> experience;

  // ── Summaries (all optional so partial data renders safely) ──
  final int videosCount;
  final int? photosCount; // TODO(M1-backend): confirm media count fields.
  final List<MediaPreviewItem> recentMedia;

  /// Kept only so existing callers keep compiling. Not shown in the UI —
  /// "Records" is not backed by the approved architecture.
  final int recordsCount;

  final int badgesCount;
  final List<String> badgeLabels; // TODO(M3-backend): map from badges API.

  final PerformanceSummary? performance; // null → empty state
  final List<AchievementItem> achievements; // empty → empty state
  final ProfileVerificationStatus verification;

  const AthleteProfileData({
    required this.name,
    required this.sport,
    required this.role,
    required this.level,
    required this.ageCategory,
    required this.gender,
    this.city,
    this.bio,
    this.sportszId,
    this.avatarEmoji,
    this.photoUrl,
    this.coverPhotoUrl,
    this.heightCm,
    this.weightKg,
    this.dominantHand,
    this.experience = const [],
    this.videosCount = 0,
    this.photosCount,
    this.recentMedia = const [],
    this.recordsCount = 0,
    this.badgesCount = 0,
    this.badgeLabels = const [],
    this.performance,
    this.achievements = const [],
    this.verification = ProfileVerificationStatus.unverified,
  });
}

// ───────────────────────── Screen ─────────────────────────

class MyProfileScreen extends ConsumerStatefulWidget {
  final AthleteProfileData? data;

  /// Screen states (no extra screen IDs).
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  // ── Navigation callbacks. Edit Profile opens the M1 edit hub. ──
  final VoidCallback? onEditCover; // TODO(M1): cover upload flow
  final VoidCallback? onEditPhoto; // TODO(M1): profile photo flow
  final Future<void> Function()? onEditProfile;
  final VoidCallback? onShareId; // TODO: I02 Share
  final VoidCallback? onViewId; // TODO: I01 SportsZ ID
  final VoidCallback? onEditAbout; // TODO: P04
  final VoidCallback? onEditSports; // TODO: P05/P06
  final VoidCallback? onEditPhysical; // TODO: P07
  final VoidCallback? onEditExperience; // TODO: P15/P16
  final VoidCallback? onViewMedia; // TODO: P17 Media Gallery
  final VoidCallback? onViewAchievements; // TODO: P12/P13
  final VoidCallback? onViewBadges; // TODO: P24/P25
  final VoidCallback? onViewVerification; // TODO: V01
  final VoidCallback? onViewPerformance; // TODO: existing M5 performance screen

  const MyProfileScreen({
    super.key,
    this.data,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.onEditCover,
    this.onEditPhoto,
    this.onEditProfile,
    this.onShareId,
    this.onViewId,
    this.onEditAbout,
    this.onEditSports,
    this.onEditPhysical,
    this.onEditExperience,
    this.onViewMedia,
    this.onViewAchievements,
    this.onViewBadges,
    this.onViewVerification,
    this.onViewPerformance,
  });

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  AthleteProfileData? _loadedProfile;
  bool _isLoading = false;
  bool _hasError = false;
  String? _loadErrorMessage;
  int? _loadErrorStatusCode;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  AthleteProfileData get _profile =>
      widget.data ??
      _loadedProfile ??
      const AthleteProfileData(
        name: '',
        sport: '',
        role: '',
        level: '',
        ageCategory: '',
        gender: '',
      );

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _isLoading = true;
      _pulse.repeat(reverse: true);
    } else if (widget.data == null) {
      // Loading updates the shared Riverpod controller state synchronously
      // before its first network await. Defer it until the first frame has
      // completed so Riverpod is not mutated while this route is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfile();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MyProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isLoading && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    var failurePhase = 'request';
    setState(() {
      _isLoading = true;
      _hasError = false;
      _loadErrorMessage = null;
      _loadErrorStatusCode = null;
    });
    _pulse.repeat(reverse: true);
    try {
      final data = await ref
          .read(profileControllerProvider.notifier)
          .loadProfile()
          .timeout(const Duration(seconds: 15));
      failurePhase = 'response-mapping';
      final profile = _profileFromJson(data);
      if (!mounted) return;
      failurePhase = 'screen-state-update';
      setState(() {
        _loadedProfile = profile;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        final apiError = apiExceptionFrom(error);
        final frames = stackTrace.toString().split('\n').take(4).join(' | ');
        debugPrint(
          '[P01] Profile load failed errorType=${error.runtimeType} '
          'status=${apiError?.statusCode ?? 'none'} phase=$failurePhase '
          'stack=$frames',
        );
      }
      if (!mounted) return;
      final apiError = apiExceptionFrom(error);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _loadErrorStatusCode = apiError?.statusCode;
        _loadErrorMessage = switch (apiError?.statusCode) {
          401 =>
            'Your session has expired. Sign in again to load your profile.',
          403 => 'This athlete profile is not available for your account.',
          404 => 'Your athlete profile could not be found.',
          _ => 'Could not load your profile. Check your connection and retry.',
        };
      });
    } finally {
      if (mounted) _pulse.stop();
    }
  }

  AthleteProfileData _profileFromJson(Map<String, dynamic> json) {
    final sports = (json['sports'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    Map<String, dynamic>? selectedSport;
    for (final sport in sports) {
      if (sport['is_primary'] == true) {
        selectedSport = sport;
        break;
      }
    }
    selectedSport ??= sports.isEmpty ? null : sports.first;

    final positions =
        (selectedSport?['positions'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
    final physical = json['physical'] as Map<String, dynamic>?;
    final experience = (json['experience'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final start = item['started_year'];
          final end = item['ended_year'];
          return ExperienceItem(
            title: item['title'] as String? ?? '',
            organization: item['organization_name'] as String? ?? '',
            duration: start == null ? '' : '$start – ${end ?? 'Present'}',
            description: item['description'] as String?,
          );
        })
        .toList();

    return AthleteProfileData(
      name: json['full_name'] as String? ?? '',
      sport:
          selectedSport?['sport_name'] as String? ??
          selectedSport?['sport_id'] as String? ??
          '',
      role: positions.join(', '),
      level: selectedSport?['level'] as String? ?? '',
      ageCategory: '',
      gender: json['gender'] as String? ?? '',
      city: [
        json['city'],
        json['region'],
      ].whereType<String>().where((part) => part.isNotEmpty).join(', '),
      bio: json['bio'] as String?,
      sportszId: json['sportsz_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      heightCm: (physical?['height_cm'] as num?)?.toDouble(),
      weightKg: (physical?['weight_kg'] as num?)?.toDouble(),
      dominantHand: physical?['dominant_hand'] as String?,
      experience: experience,
    );
  }

  void _retryLoad() {
    widget.onRetry?.call();
    _loadProfile();
  }

  void _goToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ───────────── helpers ─────────────

  TextStyle _t(
    double size,
    FontWeight w,
    Color c, {
    double? height,
    double? ls,
  }) {
    return TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: height,
      letterSpacing: ls,
    );
  }

  void _tap(VoidCallback? cb) {
    HapticFeedback.lightImpact();
    cb?.call();
  }

  Future<void> _editProfile() async {
    HapticFeedback.lightImpact();
    final openEditHub = widget.onEditProfile;
    if (openEditHub == null) return;
    await openEditHub();
    if (mounted) await _loadProfile();
  }

  void _openSportszId() {
    _tap(() {
      if (widget.onViewId != null) {
        widget.onViewId!();
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SportsZIdScreen()));
    });
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );
  }

  // ───────────── cover ─────────────

  Widget _coverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepAccent, AppColors.gold],
        ),
      ),
      child: CustomPaint(painter: _CoverPatternPainter(), size: Size.infinite),
    );
  }

  Widget _buildCover() {
    final url = _profile.coverPhotoUrl;
    final hasUrl = url != null && url.isNotEmpty;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: SizedBox(
        height: _kCoverHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasUrl)
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _coverFallback(),
                errorBuilder: (context, error, stack) => _coverFallback(),
              )
            else
              _coverFallback(),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _tap(widget.onEditCover), // TODO(M1): cover flow
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Edit Cover',
                          style: _t(11, FontWeight.w600, Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── avatar ─────────────

  Widget _avatarFallback(double size) {
    final p = _profile;
    final hasEmoji = p.avatarEmoji != null && p.avatarEmoji!.isNotEmpty;
    final initials = p.name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      color: hasEmoji ? AppColors.lightGold : AppColors.gold,
      alignment: Alignment.center,
      child: hasEmoji
          ? Text(p.avatarEmoji!, style: TextStyle(fontSize: size * 0.45))
          : Text(
              initials,
              style: _t(size * 0.35, FontWeight.w800, Colors.white),
            ),
    );
  }

  Widget _avatar(double size) {
    final url = _profile.photoUrl;
    final hasUrl = url != null && url.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: hasUrl
            ? Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.lightGold,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => _avatarFallback(size),
              )
            : _avatarFallback(size),
      ),
    );
  }

  Widget _buildAvatarCameraButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(widget.onEditPhoto), // TODO(M1): profile photo flow
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _profile.verification;
    if (status == ProfileVerificationStatus.unverified) {
      return const SizedBox.shrink();
    }
    final verified = status == ProfileVerificationStatus.verified;
    final fg = verified ? _kSuccess : AppColors.deepAccent;
    final bg = verified ? _kSuccessBg : AppColors.lightGold;
    final bd = verified ? _kSuccessBorder : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified : Icons.schedule, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Pending',
            style: _t(11, FontWeight.w600, fg),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderVisual() {
    return SizedBox(
      height: _kCoverHeight + _kAvatarOverlap,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _kCoverHeight,
            child: _buildCover(),
          ),
          Positioned(left: _kHPad, bottom: 0, child: _avatar(_kAvatarSize)),
          Positioned(
            left: _kHPad + _kAvatarSize - 34,
            bottom: 0,
            child: _buildAvatarCameraButton(),
          ),
          Positioned(
            right: _kHPad,
            top: _kCoverHeight + 10,
            child: _buildStatusChip(),
          ),
        ],
      ),
    );
  }

  // ───────────── name / header info ─────────────

  Widget _buildNameSection() {
    final p = _profile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kHPad, 8, _kHPad, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name,
            style: _t(24, FontWeight.w800, AppColors.textPrimary, height: 1.15),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.sport} · ${p.role}',
            style: _t(15, FontWeight.w500, AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.military_tech_outlined,
                size: 14,
                color: AppColors.gold,
              ),
              const SizedBox(width: 4),
              Text(p.level, style: _t(13, FontWeight.w600, AppColors.gold)),
            ],
          ),
          if (p.city != null && p.city!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    p.city!,
                    overflow: TextOverflow.ellipsis,
                    style: _t(13, FontWeight.w400, AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
          if (p.sportszId != null) ...[
            const SizedBox(height: 2),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: p.sportszId!));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: ${p.sportszId}'),
                    backgroundColor: AppColors.gold,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: AppColors.deepAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      p.sportszId!,
                      style: _t(
                        13,
                        FontWeight.w600,
                        AppColors.deepAccent,
                        ls: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.copy_outlined,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    textStyle: _t(13, FontWeight.w600, Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _tap(widget.onShareId), // TODO: I02
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  label: Text(
                    'Share ID',
                    style: _t(13, FontWeight.w600, AppColors.gold),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: const BorderSide(color: AppColors.gold, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _tap(null), // TODO: overflow menu
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────── summary row ─────────────

  Widget _buildStats() {
    final p = _profile;
    final mediaTotal = p.videosCount + (p.photosCount ?? 0);
    final matches = p.performance?.matchesCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(_kHPad, 16, _kHPad, 0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _statItem(
            Icons.perm_media_outlined,
            '$mediaTotal',
            'Media',
            widget.onViewMedia,
          ),
          Container(width: 1, height: 56, color: AppColors.divider),
          _statItem(
            Icons.insights_outlined,
            matches?.toString() ?? '–',
            'Matches',
            widget.onViewPerformance,
          ),
          Container(width: 1, height: 56, color: AppColors.divider),
          _statItem(
            Icons.military_tech_outlined,
            '${p.badgesCount}',
            'Badges',
            widget.onViewBadges,
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String value,
    String label,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _tap(onTap),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightGold,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(height: 6),
            Text(value, style: _t(20, FontWeight.w800, AppColors.textPrimary)),
            Text(
              label,
              style: _t(11, FontWeight.w400, AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── section scaffolding ─────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool editable = false,
    VoidCallback? onEdit,
    Widget? footer,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(_kHPad, 12, _kHPad, 0),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.lightGold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.gold, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: _t(16, FontWeight.w700, AppColors.textPrimary),
                  ),
                ),
                if (editable)
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => _tap(onEdit),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          child,
          if (footer != null) ...[
            const Divider(height: 1, color: AppColors.divider),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _viewAll(String label, VoidCallback? onTap) {
    return InkWell(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      onTap: () => _tap(onTap),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _t(13, FontWeight.w600, AppColors.gold)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.gold),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _t(13, FontWeight.w400, AppColors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── sections ─────────────

  Widget _buildAbout() {
    final bio = _profile.bio;
    final hasBio = bio != null && bio.trim().isNotEmpty;
    return _sectionCard(
      title: 'About',
      icon: Icons.person_outline,
      editable: true,
      onEdit: widget.onEditAbout, // TODO: P04
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          hasBio ? bio : 'No bio added yet.',
          style: _t(
            14,
            FontWeight.w400,
            hasBio ? AppColors.textPrimary : AppColors.textMuted,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSports() {
    final p = _profile;
    return _sectionCard(
      title: 'Sports',
      icon: Icons.sports_outlined,
      editable: true,
      onEdit: widget.onEditSports, // TODO: P05/P06
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGold,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.gold, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.sport} · ${p.role}',
                        style: _t(13, FontWeight.w700, AppColors.deepAccent),
                      ),
                    ],
                  ),
                ),
                if (p.ageCategory.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      p.ageCategory,
                      style: _t(12, FontWeight.w400, AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.trending_up_outlined, 'Level', p.level),
            _infoRow(Icons.person_outline, 'Gender', p.gender),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysical() {
    final p = _profile;
    final chips = <Widget>[
      if (p.heightCm != null)
        _physicalChip(
          Icons.height,
          '${p.heightCm!.toStringAsFixed(0)} cm',
          'Height',
        ),
      if (p.weightKg != null)
        _physicalChip(
          Icons.monitor_weight_outlined,
          '${p.weightKg!.toStringAsFixed(0)} kg',
          'Weight',
        ),
      if (p.dominantHand != null)
        _physicalChip(Icons.back_hand_outlined, p.dominantHand!, 'Dom. Hand'),
    ];
    final spaced = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 12));
      spaced.add(chips[i]);
    }
    return _sectionCard(
      title: 'Physical Stats',
      icon: Icons.fitness_center_outlined,
      editable: true,
      onEdit: widget.onEditPhysical, // TODO: P07
      child: chips.isEmpty
          ? _emptyState(
              'Add your height and weight to complete your profile.',
              Icons.straighten_outlined,
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: spaced),
            ),
    );
  }

  Widget _physicalChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: _t(16, FontWeight.w700, AppColors.textPrimary),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: _t(10, FontWeight.w400, AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperience() {
    final items = _profile.experience;
    return _sectionCard(
      title: 'Experience',
      icon: Icons.work_outline,
      editable: true,
      onEdit: widget.onEditExperience, // TODO: P15/P16
      child: items.isEmpty
          ? _emptyState('No experience added yet.', Icons.work_outline)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final exp = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i > 0)
                        const Divider(color: AppColors.divider, height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.lightGold,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.sports,
                              color: AppColors.gold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exp.title,
                                  style: _t(
                                    14,
                                    FontWeight.w700,
                                    AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  exp.organization,
                                  style: _t(
                                    13,
                                    FontWeight.w500,
                                    AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  exp.duration,
                                  style: _t(
                                    12,
                                    FontWeight.w400,
                                    AppColors.textMuted,
                                  ),
                                ),
                                if (exp.description != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    exp.description!,
                                    style: _t(
                                      13,
                                      FontWeight.w400,
                                      AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildPerformance() {
    final perf = _profile.performance;
    final stats = perf?.stats ?? const <PerformanceStat>[];
    Widget body;
    if (stats.isEmpty) {
      body = _emptyState(
        'Performance stats will appear here once available.',
        Icons.insights_outlined,
      );
    } else {
      final tiles = <Widget>[];
      final shown = stats.take(3).toList();
      for (var i = 0; i < shown.length; i++) {
        if (i > 0) tiles.add(const SizedBox(width: 10));
        tiles.add(
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    shown[i].value,
                    style: _t(20, FontWeight.w800, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shown[i].label,
                    textAlign: TextAlign.center,
                    style: _t(11, FontWeight.w400, AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: tiles),
      );
    }
    return _sectionCard(
      title: 'Performance',
      icon: Icons.insights_outlined,
      child: body,
      footer: _viewAll('View Performance', widget.onViewPerformance),
    );
  }

  Widget _buildAchievements() {
    final items = _profile.achievements;
    return _sectionCard(
      title: 'Achievements',
      icon: Icons.emoji_events_outlined,
      child: items.isEmpty
          ? _emptyState(
              'No achievements added yet.',
              Icons.emoji_events_outlined,
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: items.take(3).map((a) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: a.emoji != null
                              ? Text(
                                  a.emoji!,
                                  style: const TextStyle(fontSize: 18),
                                )
                              : const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 18,
                                  color: AppColors.gold,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: _t(
                                  14,
                                  FontWeight.w600,
                                  AppColors.textPrimary,
                                ),
                              ),
                              if (a.subtitle != null)
                                Text(
                                  a.subtitle!,
                                  style: _t(
                                    12,
                                    FontWeight.w400,
                                    AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
      footer: _viewAll('View All', widget.onViewAchievements),
    );
  }

  Widget _mediaTile(MediaPreviewItem item) {
    final url = item.thumbnailUrl;
    Widget placeholder() => Container(
      color: AppColors.lightGold,
      alignment: Alignment.center,
      child: Icon(
        item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: AppColors.gold,
        size: 22,
      ),
    );
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null && url.isNotEmpty)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder(),
                  errorBuilder: (context, error, stack) => placeholder(),
                )
              else
                placeholder(),
              if (item.isVideo)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedia() {
    final p = _profile;
    final total = p.videosCount + (p.photosCount ?? 0);
    final preview = p.recentMedia.take(4).toList();
    Widget body;
    if (total == 0 && preview.isEmpty) {
      body = _emptyState(
        'No media uploaded yet. Add photos and videos to showcase your game.',
        Icons.perm_media_outlined,
      );
    } else {
      final tiles = <Widget>[];
      for (var i = 0; i < preview.length; i++) {
        if (i > 0) tiles.add(const SizedBox(width: 8));
        tiles.add(_mediaTile(preview[i]));
      }
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tiles.isNotEmpty) Row(children: tiles),
            if (tiles.isNotEmpty) const SizedBox(height: 10),
            Text(
              '${p.photosCount ?? 0} photos · ${p.videosCount} videos',
              style: _t(12, FontWeight.w500, AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return _sectionCard(
      title: 'Media',
      icon: Icons.perm_media_outlined,
      child: body,
      footer: _viewAll('View All', widget.onViewMedia),
    );
  }

  Widget _buildBadges() {
    final p = _profile;
    Widget body;
    if (p.badgesCount == 0 && p.badgeLabels.isEmpty) {
      body = _emptyState('No badges earned yet.', Icons.military_tech_outlined);
    } else {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.badgeLabels.isNotEmpty)
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: p.badgeLabels.take(3).map((label) {
                  return SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.lightGold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.military_tech,
                            color: AppColors.gold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: _t(
                            11,
                            FontWeight.w500,
                            AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (p.badgeLabels.isNotEmpty) const SizedBox(height: 10),
            Text(
              '${p.badgesCount} ${p.badgesCount == 1 ? 'Badge' : 'Badges'}',
              style: _t(12, FontWeight.w500, AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return _sectionCard(
      title: 'Recognition',
      icon: Icons.military_tech_outlined,
      child: body,
      footer: _viewAll('View All', widget.onViewBadges),
    );
  }

  Widget _buildVerification() {
    final status = _profile.verification;
    late final IconData icon;
    late final Color color;
    late final String title;
    late final String subtitle;
    switch (status) {
      case ProfileVerificationStatus.verified:
        icon = Icons.verified;
        color = _kSuccess;
        title = 'Identity Verified';
        subtitle = 'Your profile is verified on SportsZ.';
        break;
      case ProfileVerificationStatus.pending:
        icon = Icons.schedule;
        color = AppColors.deepAccent;
        title = 'Verification Pending';
        subtitle = 'We are reviewing your submission.';
        break;
      case ProfileVerificationStatus.unverified:
        icon = Icons.shield_outlined;
        color = AppColors.textMuted;
        title = 'Not Verified Yet';
        subtitle = 'Verify your identity to build trust with coaches.';
        break;
    }
    return _sectionCard(
      title: 'Verification',
      icon: Icons.verified_user_outlined,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _t(14, FontWeight.w600, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: _t(
                      12,
                      FontWeight.w400,
                      AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      footer: _viewAll('View Verification', widget.onViewVerification),
    );
  }

  Widget _buildMiniIdCard() {
    final id = _profile.sportszId;
    if (id == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(_kHPad, 12, _kHPad, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFC49A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'SZ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPORTSZ ID',
                  style: _t(
                    10,
                    FontWeight.w600,
                    const Color(0xFFAAAAAA),
                    ls: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  id, // Display only — IDs are generated by the backend.
                  style: _t(17, FontWeight.w700, Colors.white, ls: 1.2),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openSportszId,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC49A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'View ID',
                style: _t(12, FontWeight.w600, Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: _t(13, FontWeight.w400, AppColors.textMuted)),
          Text(value, style: _t(13, FontWeight.w600, AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ───────────── loading / error ─────────────

  Widget _skel(double w, double h, {double r = 8, bool circle = false}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: circle ? null : BorderRadius.circular(r),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(_kHPad, 12, _kHPad, 0),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skel(120, 16),
          const SizedBox(height: 14),
          _skel(double.infinity, 12),
          const SizedBox(height: 8),
          _skel(220, 12),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _kCoverHeight + _kAvatarOverlap,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: _kCoverHeight,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                        child: _skel(double.infinity, _kCoverHeight, r: 0),
                      ),
                    ),
                    Positioned(
                      left: _kHPad,
                      bottom: 0,
                      child: _skel(_kAvatarSize, _kAvatarSize, circle: true),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_kHPad, 8, _kHPad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skel(180, 24),
                    const SizedBox(height: 8),
                    _skel(140, 14),
                    const SizedBox(height: 8),
                    _skel(100, 12),
                    const SizedBox(height: 16),
                    _skel(double.infinity, 44, r: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        _skeletonCard(),
        _skeletonCard(),
        _skeletonCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            "We couldn't load your profile",
            textAlign: TextAlign.center,
            style: _t(17, FontWeight.w700, AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _loadErrorMessage ??
                'Could not load your profile. Check your connection and retry.',
            textAlign: TextAlign.center,
            style: _t(
              13,
              FontWeight.w400,
              AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadErrorStatusCode == 401 ? _goToSignIn : _retryLoad,
            icon: Icon(
              _loadErrorStatusCode == 401 ? Icons.login : Icons.refresh,
              size: 18,
            ),
            label: Text(_loadErrorStatusCode == 401 ? 'Sign In' : 'Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 44),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: _t(13, FontWeight.w600, Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildHeaderVisual(), _buildNameSection()],
          ),
        ),
        _buildStats(),
        _buildAbout(),
        _buildSports(),
        _buildPhysical(),
        _buildExperience(),
        _buildPerformance(),
        _buildAchievements(),
        _buildMedia(),
        _buildBadges(),
        _buildVerification(),
        _buildMiniIdCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ───────────── build ─────────────

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.isLoading || _isLoading) {
      body = _buildSkeleton();
    } else if (widget.hasError || _hasError) {
      body = _buildError();
    } else {
      body = _buildContent();
    }

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            shadowColor: AppColors.border,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const SportsZLogo(
              size: 18,
              taglineColor: AppColors.textSecondary,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () {}, // TODO: overflow menu
              ),
            ],
          ),
          SliverToBoxAdapter(child: body),
        ],
      ),
    );
  }
}

// ───────────────────────── Cover fallback pattern ─────────────────────────
// Minimal, sport-agnostic geometry (diagonal lanes + concentric arcs).

class _CoverPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.2;
    for (double x = -size.height; x < size.width; x += 26) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }

    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.width * 0.88, size.height * 1.05);
    for (final r in [70.0, 110.0, 150.0]) {
      canvas.drawCircle(center, r, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
