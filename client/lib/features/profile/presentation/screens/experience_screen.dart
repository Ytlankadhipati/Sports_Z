import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'edit_experience_screen.dart';
import 'profile_edit_support.dart';

class ExperienceScreen extends ConsumerStatefulWidget {
  final Future<Map<String, dynamic>> Function()? loadProfile;
  final Future<List<Map<String, dynamic>>> Function()? loadOrganizations;
  final Future<void> Function(String id)? deleteExperience;
  const ExperienceScreen({
    super.key,
    this.loadProfile,
    this.loadOrganizations,
    this.deleteExperience,
  });
  @override
  ConsumerState<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends ConsumerState<ExperienceScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
      final profile =
          await (widget.loadProfile?.call() ??
              ref.read(profileControllerProvider.notifier).loadProfile());
      final raw = profile['experience'];
      if (!mounted) return;
      setState(() {
        _items = raw is List
            ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
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
            fallback: 'Could not load your experience. Check your connection and retry.',
          );
          _loading = false;
        });
      }
    }
  }

  Future<void> _open({Map<String, dynamic>? item}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditExperienceScreen(
          experience: item,
          loadOrganizations: widget.loadOrganizations,
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove experience?'),
        content: Text(
          'Remove “${item['title'] ?? 'this experience'}” from your profile?',
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
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.deleteExperience?.call(id) ??
          ref.read(profileControllerProvider.notifier).removeExperience(id));
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = profileRequestError(
            error,
            saving: true,
            fallback: 'Could not remove experience. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final busy = _busy;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Experience'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: loading
          ? const ProfileLoadingState()
          : _error != null && _items.isEmpty
          ? ProfileErrorState(message: _error!, onRetry: _load)
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Your experience', style: AppTypography.h1),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your teams, clubs, academies, and other experience.',
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ProfileErrorBanner(message: _error!),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text('No experience added yet.'),
                          ),
                        ),
                      for (final item in _items)
                        Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              item['title']?.toString() ?? 'Experience',
                              style: AppTypography.h4,
                            ),
                            subtitle: Text(
                              [
                                    item['organization_name']?.toString(),
                                    _duration(item),
                                  ]
                                  .whereType<String>()
                                  .where((e) => e.isNotEmpty)
                                  .join(' · '),
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !busy,
                              onSelected: (value) => value == 'edit'
                                  ? _open(item: item)
                                  : _remove(item),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove'),
                                ),
                              ],
                            ),
                            onTap: busy ? null : () => _open(item: item),
                          ),
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
                        onPressed: busy ? null : () => _open(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add experience'),
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

  String? _duration(Map<String, dynamic> item) {
    final start = item['started_year']?.toString();
    final end = item['ended_year']?.toString();
    if (start == null && end == null) return null;
    return '${start ?? '—'} – ${end ?? 'Present'}';
  }
}
