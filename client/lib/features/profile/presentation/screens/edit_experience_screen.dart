import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'profile_edit_support.dart';

class EditExperienceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? experience;
  final Future<List<Map<String, dynamic>>> Function()? loadOrganizations;
  final Future<void> Function(Map<String, dynamic>)? createExperience;
  final Future<void> Function(String id, Map<String, dynamic>)?
  updateExperience;

  const EditExperienceScreen({
    super.key,
    this.experience,
    this.loadOrganizations,
    this.createExperience,
    this.updateExperience,
  });

  @override
  ConsumerState<EditExperienceScreen> createState() =>
      _EditExperienceScreenState();
}

class _EditExperienceScreenState extends ConsumerState<EditExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _startYear = TextEditingController();
  final _endYear = TextEditingController();
  final _description = TextEditingController();
  List<Map<String, dynamic>> _organizations = [];
  String? _organizationId;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool get _editing => widget.experience != null;

  @override
  void initState() {
    super.initState();
    final item = widget.experience;
    _title.text = item?['title']?.toString() ?? '';
    _organizationId = item?['organization_id']?.toString();
    _startYear.text = item?['started_year']?.toString() ?? '';
    _endYear.text = item?['ended_year']?.toString() ?? '';
    _description.text = item?['description']?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOrganizations();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _startYear.dispose();
    _endYear.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizations =
          await (widget.loadOrganizations?.call() ??
              ref.read(profileControllerProvider.notifier).loadOrganizations());
      if (!mounted) return;
      setState(() {
        _organizations = organizations;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = profileRequestError(
            error,
            saving: false,
            fallback: 'Could not load organizations. Check your connection and retry.',
          );
          _loading = false;
        });
      }
    }
  }

  String? _yearError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1900 || year > 2100) {
      return 'Enter a year between 1900 and 2100.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final start = int.tryParse(_startYear.text.trim());
    final end = int.tryParse(_endYear.text.trim());
    if (start != null && end != null && end < start) {
      setState(() => _error = 'End year must be on or after start year.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'organization_id': _organizationId,
      'started_year': start,
      'ended_year': end,
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    };
    try {
      if (_editing) {
        await (widget.updateExperience?.call(
              widget.experience!['id'].toString(),
              payload,
            ) ??
            ref
                .read(profileControllerProvider.notifier)
                .updateExperience(
                  widget.experience!['id'].toString(),
                  payload,
                ));
      } else {
        await (widget.createExperience?.call(payload) ??
            ref
                .read(profileControllerProvider.notifier)
                .addExperience(payload));
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = profileRequestError(
            error,
            saving: true,
            fallback:
                'Could not save experience. Check your connection and retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final saving = _saving;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit experience' : 'Add experience'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: loading
          ? const ProfileLoadingState()
          : _error != null && _organizations.isEmpty
          ? ProfileErrorState(message: _error!, onRetry: _loadOrganizations)
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          _editing ? 'Update experience' : 'Add experience',
                          style: AppTypography.h1,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a team, club, academy, or other sports experience.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _title,
                          decoration: profileInputDecoration('Role or title'),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a title.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _organizationId,
                          decoration: profileInputDecoration(
                            'Organization (optional)',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No organization'),
                            ),
                            ..._organizations.map(
                              (org) => DropdownMenuItem<String>(
                                value: org['public_id']?.toString(),
                                child: Text(
                                  org['name']?.toString() ?? 'Organization',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _organizationId = value),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _startYear,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: profileInputDecoration(
                                  'Start year',
                                ),
                                validator: _yearError,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _endYear,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: profileInputDecoration('End year'),
                                validator: _yearError,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _description,
                          maxLines: 4,
                          maxLength: 1000,
                          decoration: profileInputDecoration(
                            'Description (optional)',
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
