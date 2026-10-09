import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'profile_edit_support.dart';

typedef AboutProfileLoader = Future<Map<String, dynamic>> Function();
typedef AboutProfileSaver = Future<void> Function(Map<String, dynamic> payload);

class EditAboutScreen extends ConsumerStatefulWidget {
  final AboutProfileLoader? loadProfile;
  final AboutProfileSaver? saveProfile;

  const EditAboutScreen({super.key, this.loadProfile, this.saveProfile});

  @override
  ConsumerState<EditAboutScreen> createState() => _EditAboutScreenState();
}

class _EditAboutScreenState extends ConsumerState<EditAboutScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  bool _dialogOpen = false;
  String? _error;
  String _originalBio = '';

  bool get _dirty => _controller.text != _originalBio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      final bio = profile['bio']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _controller.text = bio;
        _originalBio = bio;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = profileRequestError(
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
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {'bio': _controller.text.trim()};
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
        setState(() {
          _error = profileRequestError(
            error,
            saving: true,
            fallback:
                'Could not save your changes. Check your connection and retry.',
          );
        });
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    if (_dialogOpen || _saving) return;
    _dialogOpen = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved introduction will be lost.'),
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
    _dialogOpen = false;
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
          title: const Text('Edit about'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: loading
            ? const ProfileLoadingState()
            : _error != null && _controller.text.isEmpty
            ? ProfileErrorState(message: _error!, onRetry: _load)
            : _form(),
      ),
    );
  }

  Widget _form() => Column(
    children: [
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text('About you', style: AppTypography.h1),
              const SizedBox(height: 8),
              Text(
                'Share a short introduction with people viewing your athlete profile.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                maxLength: 500,
                maxLines: 7,
                minLines: 5,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: profileInputDecoration(
                  'About you',
                  icon: Icons.notes_outlined,
                  hint: 'Tell others a little about yourself',
                ),
                validator: (value) => (value?.length ?? 0) > 500
                    ? 'Use 500 characters or fewer.'
                    : null,
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) _inlineError(_error!),
            ],
          ),
        ),
      ),
      ProfileSaveBar(
        saving: _saving || ref.watch(profileControllerProvider).isSaving,
        onPressed: _saving || ref.watch(profileControllerProvider).isSaving
            ? null
            : _save,
        errorMessage: _error,
      ),
    ],
  );

  Widget _inlineError(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(message, style: const TextStyle(color: AppColors.error)),
  );
}
