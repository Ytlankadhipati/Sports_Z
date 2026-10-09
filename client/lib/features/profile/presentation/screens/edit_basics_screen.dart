import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/sportsz_ui.dart';
import '../controllers/profile_controller.dart';
import 'profile_edit_support.dart';

/// P03 — Edit Basics. All reads and writes are scoped to the signed-in athlete
/// by the existing /me profile API.
typedef ProfileBasicsLoader = Future<Map<String, dynamic>> Function();
typedef ProfileBasicsSaver = Future<void> Function(
  Map<String, dynamic> payload,
);

class EditBasicsScreen extends ConsumerStatefulWidget {
  final ProfileBasicsLoader? loadProfile;
  final ProfileBasicsSaver? saveProfile;

  /// Optional request hooks keep the form independently testable. Production
  /// uses the existing authenticated AuthService methods.
  const EditBasicsScreen({super.key, this.loadProfile, this.saveProfile});

  @override
  ConsumerState<EditBasicsScreen> createState() => _EditBasicsScreenState();
}

class _EditBasicsScreenState extends ConsumerState<EditBasicsScreen> {
  bool get _isSaving => _saving || ref.read(profileControllerProvider).isSaving;
  static const _genderOptions = <String>[
    'female',
    'male',
    'non_binary',
    'prefer_not_to_say',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  bool _discardDialogOpen = false;
  String? _loadError;
  String? _saveError;
  String? _gender;
  DateTime? _dateOfBirth;
  DateTime? _originalDateOfBirth;
  String? _dateError;
  Map<String, String> _originalValues = const {};

  bool get _hasUnsavedChanges {
    return _nameController.text != (_originalValues['full_name'] ?? '') ||
        _gender != _originalValues['gender'] ||
        _cityController.text != (_originalValues['city'] ?? '') ||
        _regionController.text != (_originalValues['region'] ?? '') ||
        _dateOfBirth != _originalDateOfBirth;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile =
          await (widget.loadProfile?.call() ??
              ref.read(profileControllerProvider.notifier).loadProfile());
      final dob = DateTime.tryParse(profile['date_of_birth']?.toString() ?? '');
      final name = profile['full_name']?.toString().trim() ?? '';
      final gender = profile['gender']?.toString().trim() ?? '';
      final city = profile['city']?.toString().trim() ?? '';
      final region = profile['region']?.toString().trim() ?? '';

      if (!mounted) return;
      setState(() {
        _nameController.text = name;
        _gender = gender.isEmpty ? null : gender;
        _cityController.text = city;
        _regionController.text = region;
        _dateOfBirth = dob;
        _originalDateOfBirth = dob;
        _originalValues = {
          'full_name': name,
          'gender': gender,
          'city': city,
          'region': region,
        };
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = profileRequestError(
            error,
            saving: false,
            fallback:
                'Could not load your profile. Check your connection and retry.',
          );
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (_dateOfBirth == null) {
      setState(() => _dateError = 'Select your date of birth.');
    } else if (_dateOfBirth!.isBefore(DateTime(1900)) ||
        _dateOfBirth!.isAfter(DateTime.now())) {
      setState(() => _dateError = 'Choose a valid date of birth.');
    }
    if (!valid || _dateOfBirth == null || _dateError != null) {
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
      _dateError = null;
    });
    try {
      final payload = {
        'full_name': _nameController.text.trim(),
        'date_of_birth': _dateIso(_dateOfBirth!),
        'gender': _gender!.trim(),
        'city': _cityController.text.trim(),
        'region': _regionController.text.trim(),
      };
      await (widget.saveProfile?.call(payload) ??
          ref.read(profileControllerProvider.notifier).saveProfile(payload));

      if (!mounted) return;
      setState(() {
        _saving = false;
        _allowPop = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _saveError = profileRequestError(
            error,
            saving: true,
            fallback:
                'Could not save your changes. Check your connection and retry.',
          ),
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    var initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    if (initial.isAfter(now)) initial = now;
    if (initial.isBefore(DateTime(1900))) initial = DateTime(1900);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.gold,
            secondary: AppColors.deepAccent,
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateOfBirth = DateTime(selected.year, selected.month, selected.day);
      _dateError = null;
      _saveError = null;
    });
  }

  String _dateIso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Future<void> _confirmDiscard() async {
    if (_discardDialogOpen || _saving) return;
    _discardDialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved profile changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _discardDialogOpen = false;
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  void _handlePop(bool didPop, Object? result) {
    if (!didPop && _hasUnsavedChanges) _confirmDiscard();
  }

  String _prettyGender(String value) => switch (value) {
    'female' => 'Female',
    'male' => 'Male',
    'non_binary' => 'Non-binary',
    'prefer_not_to_say' => 'Prefer not to say',
    _ => value,
  };

  List<String> get _availableGenders {
    final current = _gender;
    if (current != null && !_genderOptions.contains(current)) {
      return [..._genderOptions, current];
    }
    return _genderOptions;
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final saving = _saving;
    return PopScope<Object?>(
      canPop: _allowPop || (!_hasUnsavedChanges && !saving),
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Edit basics'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: loading
            ? _loadingState()
            : _loadError != null
            ? _errorState()
            : _editForm(),
      ),
    );
  }

  Widget _loadingState() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.gold),
        SizedBox(height: 16),
        Text('Loading your profile…', style: AppTypography.bodyMedium),
      ],
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 170,
            child: GoldButton(label: 'Retry', onPressed: _loadProfile),
          ),
        ],
      ),
    ),
  );

  Widget _editForm() => Column(
    children: [
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text('Basic information', style: AppTypography.h1),
              const SizedBox(height: 8),
              Text(
                'Keep your athlete identity up to date.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              _sectionLabel('PROFILE DETAILS'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: _decoration('Full name', Icons.person_outline),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Enter your full name.';
                  if (name.length > 120) return 'Use 120 characters or fewer.';
                  return null;
                },
                onChanged: (_) => setState(() => _saveError = null),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                isExpanded: true,
                decoration: _decoration('Gender', Icons.wc_outlined),
                items: _availableGenders
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_prettyGender(value)),
                      ),
                    )
                    .toList(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Choose your gender.';
                  }
                  if (value.trim().length > 40) {
                    return 'Use 40 characters or fewer.';
                  }
                  return null;
                },
                onChanged: (value) => setState(() {
                  _gender = value;
                  _saveError = null;
                }),
              ),
              const SizedBox(height: 16),
              _dateOfBirthField(),
              const SizedBox(height: 24),
              _sectionLabel('LOCATION (OPTIONAL)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: _decoration('City', Icons.location_city_outlined),
                validator: (value) => (value?.trim().length ?? 0) > 120
                    ? 'Use 120 characters or fewer.'
                    : null,
                onChanged: (_) => setState(() => _saveError = null),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: _decoration('Region / state', Icons.map_outlined),
                validator: (value) => (value?.trim().length ?? 0) > 120
                    ? 'Use 120 characters or fewer.'
                    : null,
                onChanged: (_) => setState(() => _saveError = null),
              ),
            ],
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saveError != null) ...[
                _errorBanner(_saveError!),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: GoldButton(
                  label: 'Save changes',
                  icon: Icons.check,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _dateOfBirthField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Date of birth', style: AppTypography.labelLarge),
      const SizedBox(height: 8),
      Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _saving ? null : _pickDate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _dateError == null ? AppColors.border : AppColors.error,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateOfBirth == null
                        ? 'Select date of birth'
                        : _formatDate(_dateOfBirth!),
                    style: AppTypography.bodyLarge.copyWith(
                      color: _dateOfBirth == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.deepAccent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
      if (_dateError != null) ...[
        const SizedBox(height: 6),
        Text(
          _dateError!,
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ] else ...[
        const SizedBox(height: 6),
        Text(
          'Your exact date of birth is kept private.',
          style: AppTypography.bodySmall,
        ),
      ],
    ],
  );

  Widget _sectionLabel(String label) => Text(
    label,
    style: AppTypography.labelMedium.copyWith(
      color: AppColors.deepAccent,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    ),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.surface,
    counterStyle: AppTypography.labelSmall,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );

  Widget _errorBanner(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
