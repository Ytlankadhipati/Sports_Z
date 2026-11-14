import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/connections/data/models/connection_item.dart';
import 'package:sports_z/features/connections/presentation/controllers/connections_controller.dart';
import 'package:sports_z/features/connections/presentation/screens/connect_screen.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// C02 Connections: incoming requests (accept / decline), sent, and connected people.
class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  String _tab = 'incoming';

  bool _matches(ConnectionItem c) => switch (_tab) {
    'incoming' => c.isIncomingRequest,
    'sent' => c.isSentRequest,
    _ => c.status == 'accepted',
  };

  Future<void> _respond(ConnectionItem c, bool accept) async {
    final ok = await m4Run(
      context,
      () => ref
          .read(connectionsRepositoryProvider)
          .respond(c.id, accept: accept)
          .then((_) {}),
      success: accept ? 'Connected' : 'Request declined',
    );
    if (ok) ref.invalidate(connectionsProvider);
  }

  Future<void> _block(ConnectionItem c) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Block ${c.counterpart.displayName}?'),
        content: const Text(
          'They will not be able to find you, view your profile or message you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await m4Run(
      context,
      () => ref
          .read(connectionsRepositoryProvider)
          .blockUser(c.counterpart.userId)
          .then((_) {}),
      success: 'Blocked',
    );
    if (ok) {
      ref.invalidate(connectionsProvider);
      ref.invalidate(blockedUsersProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider);
    return M4Page(
      title: 'Connections',
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add_alt_1, color: AppColors.gold),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ConnectScreen()),
          ),
        ),
      ],
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                M4Pill(
                  label: 'Requests',
                  selected: _tab == 'incoming',
                  onTap: () => setState(() => _tab = 'incoming'),
                ),
                M4Pill(
                  label: 'Sent',
                  selected: _tab == 'sent',
                  onTap: () => setState(() => _tab = 'sent'),
                ),
                M4Pill(
                  label: 'Connected',
                  selected: _tab == 'connected',
                  onTap: () => setState(() => _tab = 'connected'),
                ),
              ],
            ),
          ),
          Expanded(
            child: m4Async<List<ConnectionItem>>(
              connections,
              onRetry: () => ref.invalidate(connectionsProvider),
              data: (items) {
                final shown = items.where(_matches).toList();
                if (shown.isEmpty) {
                  return const M4Message(
                    icon: Icons.people_outline,
                    text: 'Nothing here yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(connectionsProvider.future),
                  child: ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _tile(shown[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(ConnectionItem c) {
    return M4Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              M4Avatar(c.counterpart),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.counterpart.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (c.counterpart.role != null)
                      Text(
                        c.counterpart.role!,
                        style: const TextStyle(color: Colors.white54),
                      ),
                  ],
                ),
              ),
              M4StatusChip(c.status),
            ],
          ),
          if (c.note != null && c.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c.note!, style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (c.isIncomingRequest) ...[
                ElevatedButton(
                  onPressed: () => _respond(c, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _respond(c, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Decline'),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => _block(c),
                child: const Text(
                  'Block',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
