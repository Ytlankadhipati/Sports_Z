import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/privacy_access/data/models/privacy_models.dart';
import 'package:sports_z/features/privacy_access/presentation/controllers/privacy_access_controller.dart';

/// PR08 View as: shows exactly what each audience sees of my profile.
/// The server runs the same project() it uses for real viewers.
class ViewAsScreen extends ConsumerStatefulWidget {
  const ViewAsScreen({super.key, this.audiences = const []});

  /// From GET /me/privacy/schema. Falls back to the five known audiences.
  final List<String> audiences;

  @override
  ConsumerState<ViewAsScreen> createState() => _ViewAsScreenState();
}

class _ViewAsScreenState extends ConsumerState<ViewAsScreen> {
  static const _fallback = [
    'athlete',
    'coach',
    'linked_coach',
    'recruiter',
    'public',
  ];

  late final List<String> _options = widget.audiences.isEmpty
      ? _fallback
      : widget.audiences;
  late String _audience = _options.first;

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(profilePreviewProvider(_audience));
    return M4Page(
      title: 'View as',
      subtitle: 'This is what ${audienceLabel(_audience).toLowerCase()} sees.',
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final a in _options)
                  M4Pill(
                    label: audienceLabel(a),
                    selected: a == _audience,
                    onTap: () => setState(() => _audience = a),
                  ),
              ],
            ),
          ),
          Expanded(
            child: m4Async<Map<String, dynamic>>(
              preview,
              onRetry: () => ref.invalidate(profilePreviewProvider(_audience)),
              data: (fields) {
                if (fields.isEmpty) {
                  return const M4Message(
                    icon: Icons.visibility_off_outlined,
                    text: 'Nothing is visible to this audience.',
                  );
                }
                final keys = fields.keys.toList()..sort();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final key in keys)
                      M4Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fieldLabel(key),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _display(fields[key]),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Short readable form of any JSON value.
  String _display(Object? value) {
    if (value == null) return '—';
    if (value is List) {
      if (value.isEmpty) return '—';
      return value.map(_display).join(', ');
    }
    if (value is Map) {
      final name = value['sport_name'] ?? value['title'] ?? value['name'];
      if (name is String) return name;
      return value.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
    }
    return value.toString();
  }
}
