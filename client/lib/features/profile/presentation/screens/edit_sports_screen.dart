import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'edit_sport_screen.dart';
import 'profile_edit_support.dart';

class EditSportsScreen extends ConsumerStatefulWidget {
  final Future<Map<String, dynamic>> Function()? loadProfile;
  final Future<void> Function(String sportId)? deleteSport;
  final Future<void> Function(String sportId)? setPrimary;

  const EditSportsScreen({
    super.key,
    this.loadProfile,
    this.deleteSport,
    this.setPrimary,
  });

  @override
  ConsumerState<EditSportsScreen> createState() => _EditSportsScreenState();
}

class _EditSportsScreenState extends ConsumerState<EditSportsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _sports = [];

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
      final data =
          await (widget.loadProfile?.call() ??
              ref.read(profileControllerProvider.notifier).loadProfile());
      final raw = data['sports'];
      if (!mounted) return;
      setState(() {
        _sports = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = profileRequestError(
            error,
            saving: false,
            fallback:
                'Could not load your sports. Check your connection and retry.',
          );
          _loading = false;
        });
      }
    }
  }

  Future<void> _mutate(String sportId, {required bool primary}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (primary) {
        await (widget.setPrimary?.call(sportId) ??
            ref
                .read(profileControllerProvider.notifier)
                .setPrimarySport(sportId));
      } else {
        await (widget.deleteSport?.call(sportId) ??
            ref.read(profileControllerProvider.notifier).removeSport(sportId));
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = profileRequestError(
            error,
            saving: true,
            fallback: 'Could not update your sports. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> sport) async {
    final id = sport['sport_id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this sport?'),
        content: Text(
          'Remove ${sport['sport_name'] ?? sport['name'] ?? 'this sport'} from your profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _mutate(id, primary: false);
  }

  Future<void> _edit({String? sportId}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditSportScreen(sportId: sportId)),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final busy = _busy;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your sports'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: loading
          ? const ProfileLoadingState()
          : _error != null && _sports.isEmpty
          ? ProfileErrorState(message: _error!, onRetry: _load)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Manage sports', style: AppTypography.h1),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a primary sport, update its details, or remove it from your profile.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ProfileErrorBanner(message: _error!),
                      if (_sports.isEmpty) const _EmptySports(),
                      for (final sport in _sports)
                        _SportCard(
                          sport: sport,
                          busy: busy,
                          onEdit: () =>
                              _edit(sportId: sport['sport_id']?.toString()),
                          onPrimary: () => _mutate(
                            sport['sport_id'].toString(),
                            primary: true,
                          ),
                          onRemove: () => _remove(sport),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => _edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add a sport'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SportCard extends StatelessWidget {
  final Map<String, dynamic> sport;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onPrimary;
  final VoidCallback onRemove;
  const _SportCard({
    required this.sport,
    required this.busy,
    required this.onEdit,
    required this.onPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        sport['sport_name']?.toString() ?? sport['name']?.toString() ?? 'Sport';
    final primary = sport['is_primary'] == true;
    final positions = sport['positions'] is List
        ? (sport['positions'] as List).join(' · ')
        : '';
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: AppTypography.h4)),
                if (primary)
                  const Chip(
                    label: Text('Primary'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (positions.isNotEmpty || sport['level'] != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (positions.isNotEmpty) positions,
                  if (sport['level'] != null) sport['level'].toString(),
                ].join(' · '),
                style: AppTypography.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Edit details'),
                ),
                if (!primary)
                  TextButton(
                    onPressed: busy ? null : onPrimary,
                    child: const Text('Set primary'),
                  ),
                TextButton(
                  onPressed: busy ? null : onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySports extends StatelessWidget {
  const _EmptySports();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 36),
    child: Center(child: Text('No sports added yet.')),
  );
}
