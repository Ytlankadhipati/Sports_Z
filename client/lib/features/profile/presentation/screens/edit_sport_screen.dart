import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'profile_edit_support.dart';

class EditSportScreen extends ConsumerStatefulWidget {
  final String? sportId;
  final Future<Map<String, dynamic>> Function()? loadProfile;
  final Future<List<Map<String, dynamic>>> Function()? loadSports;
  final Future<Map<String, dynamic>> Function(String id)? loadConfig;
  final Future<void> Function(String id, Map<String, dynamic> payload)?
  saveSport;

  const EditSportScreen({
    super.key,
    this.sportId,
    this.loadProfile,
    this.loadSports,
    this.loadConfig,
    this.saveSport,
  });

  @override
  ConsumerState<EditSportScreen> createState() => _EditSportScreenState();
}

class _EditSportScreenState extends ConsumerState<EditSportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _positions = TextEditingController();
  final _level = TextEditingController();
  List<Map<String, dynamic>> _catalog = [];
  String? _sportId;
  String? _sportName;
  bool _loading = true;
  bool _saving = false;
  bool _dynamicFieldsAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _positions.dispose();
    _level.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait<Object>([
        widget.loadSports?.call() ??
            ref.read(profileControllerProvider.notifier).loadSportsCatalog(),
        widget.loadProfile?.call() ??
            ref.read(profileControllerProvider.notifier).loadProfile(),
      ]);
      final catalog = responses[0] as List<Map<String, dynamic>>;
      final profileSports = (responses[1] as Map<String, dynamic>)['sports'];
      final current = profileSports is List
          ? profileSports
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      String? id = widget.sportId;
      Map<String, dynamic>? selected = _findById(current, id);
      id ??= selected?['sport_id']?.toString();
      if (id == null && current.isNotEmpty) {
        selected = current.first;
        id = selected['sport_id']?.toString();
      }
      if (id != null) {
        final configData =
            await (widget.loadConfig?.call(id) ??
                ref
                    .read(profileControllerProvider.notifier)
                    .loadSportConfig(id));
        final sport = configData['sport'];
        final config = sport is Map ? sport['config'] : null;
        _dynamicFieldsAvailable =
            config is Map &&
            config['fields'] is List &&
            (config['fields'] as List).isNotEmpty;
      }
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _sportId = id;
        _sportName =
            selected?['sport_name']?.toString() ??
            selected?['name']?.toString() ??
            _findById(catalog, id)?['name']?.toString();
        _positions.text = selected?['positions'] is List
            ? (selected!['positions'] as List).join(', ')
            : '';
        _level.text = selected?['level']?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = profileRequestError(
            error,
            saving: false,
            fallback: 'Could not load sport details. Check your connection and retry.',
          );
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectSport(String? value) async {
    if (value == null) return;
    setState(() {
      _sportId = value;
      _sportName = _findById(_catalog, value)?['name']?.toString();
      _positions.clear();
      _level.clear();
      _dynamicFieldsAvailable = false;
    });
    try {
      final data =
          await (widget.loadConfig?.call(value) ??
              ref
                  .read(profileControllerProvider.notifier)
                  .loadSportConfig(value));
      final sport = data['sport'];
      final config = sport is Map ? sport['config'] : null;
      if (mounted) {
        setState(
          () => _dynamicFieldsAvailable =
              config is Map &&
              config['fields'] is List &&
              (config['fields'] as List).isNotEmpty,
        );
      }
    } catch (_) {
      /* The catalog remains usable if optional config is unavailable. */
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final id = _sportId;
    if (id == null) {
      setState(() => _error = 'Choose a sport first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final positions = _positions.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final payload = {
        'positions': positions,
        'level': _level.text.trim().isEmpty ? null : _level.text.trim(),
      };
      await (widget.saveSport?.call(id, payload) ??
          ref.read(profileControllerProvider.notifier).saveSport(id, payload));
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = profileRequestError(
            error,
            saving: true,
            fallback: 'Could not save sport details. Check your connection and retry.',
          ),
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final saving = _saving;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.sportId == null ? 'Add a sport' : 'Edit sport'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: loading
          ? const ProfileLoadingState()
          : _error != null && _catalog.isEmpty
          ? ProfileErrorState(message: _error!, onRetry: _load)
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('Sport details', style: AppTypography.h1),
                        const SizedBox(height: 8),
                        Text(
                          'Select a sport and update the details supported by your profile.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: _sportId,
                          decoration: profileInputDecoration(
                            'Sport',
                            icon: Icons.sports_outlined,
                          ),
                          items: _catalog
                              .map(
                                (sport) => DropdownMenuItem(
                                  value: sport['sport_id']?.toString(),
                                  child: Text(
                                    sport['name']?.toString() ?? 'Sport',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: widget.sportId != null
                              ? null
                              : _selectSport,
                          validator: (value) =>
                              value == null ? 'Choose a sport.' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _positions,
                          decoration: profileInputDecoration(
                            'Positions',
                            hint: 'Separate positions with commas',
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _level,
                          decoration: profileInputDecoration('Level'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        if (_sportName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Editing $_sportName',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        if (_dynamicFieldsAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This sport has configured fields that are left unchanged because the shared M2 ConfigFormRenderer is not available in this client build.',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ProfileErrorBanner(message: _error!),
                          ),
                      ],
                    ),
                  ),
                ),
                ProfileSaveBar(
                  saving: saving,
                  onPressed: saving ? null : _save,
                ),
              ],
            ),
    );
  }
}

Map<String, dynamic>? _findById(List<Map<String, dynamic>> items, String? id) {
  for (final item in items) {
    if (item['sport_id']?.toString() == id) return item;
  }
  return null;
}
