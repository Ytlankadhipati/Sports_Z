import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/connections/data/models/connection_item.dart';
import 'package:sports_z/features/connections/presentation/controllers/connections_controller.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';

/// PR09 Blocked users: people I blocked, with Unblock.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    ConnectionItem c,
  ) async {
    final ok = await m4Run(
      context,
      () => ref.read(connectionsRepositoryProvider).unblock(c.id),
      success: 'Unblocked',
    );
    if (ok) {
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(connectionsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    return M4Page(
      title: 'Blocked users',
      subtitle: 'Blocked people cannot find you, view your profile or message you.',
      child: m4Async<List<ConnectionItem>>(
        blocked,
        onRetry: () => ref.invalidate(blockedUsersProvider),
        data: (items) {
          if (items.isEmpty) {
            return const M4Message(
              icon: Icons.shield_outlined,
              text: 'You have not blocked anyone.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(blockedUsersProvider.future),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                return M4Card(
                  child: Row(
                    children: [
                      M4Avatar(c.counterpart),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.counterpart.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _unblock(context, ref, c),
                        child: const Text('Unblock'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
