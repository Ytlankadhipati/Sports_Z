import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'profile_edit_support.dart';

typedef PhysicalProfileLoader = Future<Map<String, dynamic>> Function();
typedef PhysicalProfileSaver = Future<void> Function(
  Map<String, dynamic> payload,
);

class EditPhysicalScreen extends ConsumerStatefulWidget {
  final PhysicalProfileLoader? loadProfile;
  final PhysicalProfileSaver? saveProfile;

  const EditPhysicalScreen({super.key, this.loadProfile, this.saveProfile});

  @override
  ConsumerState<EditPhysicalScreen> createState() => _EditPhysicalScreenState();
}

class _EditPhysicalScreenState extends ConsumerState<EditPhysicalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _handController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  bool _discardDialogOpen = false;
  String? _error;
  Map<String, String> _original = const {};

  bool get _dirty =>
      _heightController.text != (_original['height_cm'] ?? '') ||
      _weightController.text != (_original['weight_kg'] ?? '') ||
      _handController.text != (_original['dominant_hand'] ?? '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _handController.dispose();
    super.dispose();
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
      final physical = data['physical'] is Map
          ? Map<String, dynamic>.from(data['physical'] as Map)
          : <String, dynamic>{};
      final height = physical['height_cm']?.toString() ?? '';
      final weight = physical['weight_kg']?.toString() ?? '';
      final hand = physical['dominant_hand']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _heightController.text = height;
        _weightController.text = weight;
        _handController.text = hand;
        _original = {
          'height_cm': height,
          'weight_kg': weight,
          'dominant_hand': hand,
        };
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = profileRequestError(
            error,
            saving: false,
            fallback: 'Could not load your physical details. Check your connection and retry.',
          );
          _loading = false;
        });
      }
    }
  }

  String? _numberError(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null) return 'Enter a valid $label.';
    if (number < min || number > max) {
      return 'Enter a $label between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final height = double.tryParse(_heightController.text.trim());
      final weight = double.tryParse(_weightController.text.trim());
      final payload = {
        'height_cm': height,
        'weight_kg': weight,
        'dominant_hand': _handController.text.trim().isEmpty
            ? null
            : _handController.text.trim(),
      };
      await (widget.saveProfile?.call(payload) ??
          ref.read(profileControllerProvider.notifier).savePhysical(payload));
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
          () => _error = profileRequestError(
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

  Future<void> _confirmDiscard() async {
    if (_discardDialogOpen || _saving) return;
    _discardDialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved physical details will be lost.'),
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

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final saving = _saving;
    return PopScope<Object?>(
      canPop: _allowPop || (!_dirty && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dirty) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Physical details'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: loading
            ? const ProfileLoadingState()
            : _error != null && _original.isEmpty
            ? ProfileErrorState(message: _error!, onRetry: _load)
            : _form(),
      ),
    );
  }

  Widget _form() {
    final saving = _saving || ref.watch(profileControllerProvider).isSaving;
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text('Physical information', style: AppTypography.h1),
                const SizedBox(height: 8),
                Text(
                  'Measurements are optional and can be updated at any time.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(7)],
                  decoration: profileInputDecoration(
                    'Height (cm)',
                    icon: Icons.height,
                  ),
                  validator: (value) =>
                      _numberError(value, min: 30, max: 300, label: 'height'),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(7)],
                  decoration: profileInputDecoration(
                    'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                  ),
                  validator: (value) =>
                      _numberError(value, min: 1, max: 500, label: 'weight'),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _handController,
                  textCapitalization: TextCapitalization.words,
                  decoration: profileInputDecoration(
                    'Dominant hand',
                    icon: Icons.back_hand_outlined,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 8),
                Text(
                  'Leave a measurement blank to clear it.',
                  style: AppTypography.bodySmall,
                ),
                if (_error != null) _inlineError(_error!),
              ],
            ),
          ),
        ),
        ProfileSaveBar(
          saving: saving,
          onPressed: saving ? null : _save,
          errorMessage: _error,
        ),
      ],
    );
  }

  Widget _inlineError(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(message, style: const TextStyle(color: AppColors.error)),
  );
}
