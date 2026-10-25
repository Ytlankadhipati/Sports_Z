import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/connections/presentation/screens/connections_screen.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/privacy_access/data/models/privacy_models.dart';
import 'package:sports_z/features/privacy_access/presentation/controllers/privacy_access_controller.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/access_grants_screen.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/blocked_users_screen.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/view_as_screen.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// PR01 Privacy center: who can find you, who can contact you, which profile
/// fields are hidden, plus shortcuts to access grants, view-as and blocked users.
class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schema = ref.watch(privacySchemaProvider);
    final settings = ref.watch(privacySettingsProvider);

    void retry() {
      ref.invalidate(privacySchemaProvider);
      ref.invalidate(privacySettingsProvider);
    }

    return M4Page(
      title: 'Privacy',
      subtitle: 'You control what others can see.',
      child: m4Async<PrivacySchema>(
        schema,
        onRetry: retry,
        data: (s) => m4Async<PrivacySettingsValue>(
          settings,
          onRetry: retry,
          data: (v) => _PrivacyForm(schema: s, initial: v),
        ),
      ),
    );
  }
}

class _PrivacyForm extends ConsumerStatefulWidget {
  const _PrivacyForm({required this.schema, required this.initial});
  final PrivacySchema schema;
  final PrivacySettingsValue initial;

  @override
  ConsumerState<_PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends ConsumerState<_PrivacyForm> {
  late PrivacySettingsValue _value = widget.initial;
  bool _saving = false;

  bool get _dirty {
    final a = _value;
    final b = widget.initial;
    return a.discoverable != b.discoverable ||
        a.contactPolicy != b.contactPolicy ||
        a.hiddenFields.length != b.hiddenFields.length ||
        !a.hiddenFields.containsAll(b.hiddenFields);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await m4Run(
      context,
      () => ref.read(privacyAccessRepositoryProvider).saveSettings(_value),
      success: 'Privacy settings saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) ref.invalidate(privacySettingsProvider);
  }

  void _toggleField(String field, bool visible) {
    final hidden = {..._value.hiddenFields};
    if (visible) {
      hidden.remove(field);
    } else {
      hidden.add(field);
    }
    setState(() => _value = _value.copyWith(hiddenFields: hidden));
  }

  Widget _link(IconData icon, String title, Widget Function() screen) {
    return M4Card(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen())),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schema;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        M4Card(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _value.discoverable,
            onChanged: (on) =>
                setState(() => _value = _value.copyWith(discoverable: on)),
            title: const Text(
              'Discoverable',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Let others find your profile in search.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
        if (s.contactPolicyOptions.isNotEmpty)
          M4Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who can contact you',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  runSpacing: 4,
                  children: [
                    for (final option in s.contactPolicyOptions)
                      M4Pill(
                        label: contactPolicyLabel(option),
                        selected: _value.contactPolicy == option,
                        onTap: () => setState(
                          () => _value = _value.copyWith(contactPolicy: option),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        M4Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile fields',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Turn a field off to hide it from everyone except you.',
                style: TextStyle(color: Colors.white54),
              ),
              for (final f in s.fields)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: !_value.hiddenFields.contains(f.field),
                  onChanged: f.field.isEmpty
                      ? null
                      : (visible) => _toggleField(f.field, visible),
                  title: Text(
                    fieldLabel(f.field),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            onPressed: (_dirty && !_saving) ? _save : null,
            style: m4PrimaryButton(),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ),
        _link(
          Icons.visibility_outlined,
          'View my profile as…',
          () => ViewAsScreen(audiences: s.previewAudiences),
        ),
        _link(
          Icons.key_outlined,
          'Access grants',
          () => const AccessGrantsScreen(),
        ),
        _link(
          Icons.people_outline,
          'Connections',
          () => const ConnectionsScreen(),
        ),
        _link(
          Icons.block,
          'Blocked users',
          () => const BlockedUsersScreen(),
        ),
      ],
    );
  }
}
