import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/privacy_access/data/models/access_grant_item.dart';
import 'package:sports_z/features/privacy_access/presentation/controllers/privacy_access_controller.dart';
import 'package:sports_z/features/privacy_access/presentation/screens/grant_detail_screen.dart';

/// PR06 Access grants: what I share ("owner") and what others shared with me ("grantee").
class AccessGrantsScreen extends ConsumerStatefulWidget {
  const AccessGrantsScreen({super.key});

  @override
  ConsumerState<AccessGrantsScreen> createState() => _AccessGrantsScreenState();
}

class _AccessGrantsScreenState extends ConsumerState<AccessGrantsScreen> {
  String _role = 'owner';

  @override
  Widget build(BuildContext context) {
    final grants = ref.watch(accessGrantsProvider(_role));
    return M4Page(
      title: 'Access grants',
      subtitle: 'Who can see more of your profile, and for how long.',
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                M4Pill(
                  label: 'Shared by me',
                  selected: _role == 'owner',
                  onTap: () => setState(() => _role = 'owner'),
                ),
                M4Pill(
                  label: 'Shared with me',
                  selected: _role == 'grantee',
                  onTap: () => setState(() => _role = 'grantee'),
                ),
              ],
            ),
          ),
          Expanded(
            child: m4Async<List<AccessGrantItem>>(
              grants,
              onRetry: () => ref.invalidate(accessGrantsProvider(_role)),
              data: (items) {
                if (items.isEmpty) {
                  return const M4Message(
                    icon: Icons.key_off_outlined,
                    text: 'No access grants yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(accessGrantsProvider(_role).future),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => _tile(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(AccessGrantItem g) {
    return M4Card(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GrantDetailScreen(grant: g)),
        );
        ref.invalidate(accessGrantsProvider(_role));
      },
      child: Row(
        children: [
          M4Avatar(g.counterpart),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.counterpart.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  g.scopes.map(scopeLabel).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          M4StatusChip(g.status),
        ],
      ),
    );
  }
}
