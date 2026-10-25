import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/coach_links/data/models/coach_link_item.dart';
import 'package:sports_z/features/coach_links/presentation/controllers/coach_links_controller.dart';
import 'package:sports_z/features/coach_links/presentation/screens/coach_link_detail_screen.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// L01 Coach links: requests waiting for me, active links, and past links.
class CoachLinksScreen extends ConsumerStatefulWidget {
  const CoachLinksScreen({super.key});

  @override
  ConsumerState<CoachLinksScreen> createState() => _CoachLinksScreenState();
}

class _CoachLinksScreenState extends ConsumerState<CoachLinksScreen> {
  String _tab = 'requests';

  bool _matches(CoachLinkItem l) => switch (_tab) {
    'requests' => l.status == 'requested',
    'active' => l.isActive,
    _ => l.status == 'declined' || l.status == 'ended',
  };

  Future<void> _decide(CoachLinkItem l, {required bool approve}) async {
    final repo = ref.read(coachLinksRepositoryProvider);
    final ok = await m4Run(
      context,
      () => (approve ? repo.approve(l.id) : repo.decline(l.id)).then((_) {}),
      success: approve ? 'Coach linked' : 'Request declined',
    );
    if (ok) ref.invalidate(coachLinksProvider);
  }

  Future<void> _openRequestDialog() async {
    final coachId = TextEditingController();
    final sportId = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request a coach link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: coachId,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            TextField(
              controller: sportId,
              decoration: const InputDecoration(labelText: 'Sport ID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    final counterpart = coachId.text.trim();
    final sport = sportId.text.trim();
    coachId.dispose();
    sportId.dispose();
    if (send != true || !mounted) return;
    if (counterpart.isEmpty || sport.isEmpty) {
      m4Snack(context, 'User ID and sport are required.');
      return;
    }
    final ok = await m4Run(
      context,
      () => ref
          .read(coachLinksRepositoryProvider)
          .request(counterpart, sport)
          .then((_) {}),
      success: 'Link request sent',
    );
    if (ok) ref.invalidate(coachLinksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(coachLinksProvider);
    return M4Page(
      title: 'Coach links',
      subtitle: 'People who coach you, and requests to link.',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_link, color: AppColors.gold),
          onPressed: _openRequestDialog,
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
                  selected: _tab == 'requests',
                  onTap: () => setState(() => _tab = 'requests'),
                ),
                M4Pill(
                  label: 'Active',
                  selected: _tab == 'active',
                  onTap: () => setState(() => _tab = 'active'),
                ),
                M4Pill(
                  label: 'Past',
                  selected: _tab == 'past',
                  onTap: () => setState(() => _tab = 'past'),
                ),
              ],
            ),
          ),
          Expanded(
            child: m4Async<List<CoachLinkItem>>(
              links,
              onRetry: () => ref.invalidate(coachLinksProvider),
              data: (items) {
                final shown = items.where(_matches).toList();
                if (shown.isEmpty) {
                  return const M4Message(
                    icon: Icons.sports,
                    text: 'No coach links here yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(coachLinksProvider.future),
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

  Widget _tile(CoachLinkItem l) {
    return M4Card(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CoachLinkDetailScreen(link: l),
          ),
        );
        ref.invalidate(coachLinksProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              M4Avatar(l.counterpart),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.counterpart.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      l.sportId,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              M4StatusChip(l.status),
            ],
          ),
          if (l.needsMyResponse) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _decide(l, approve: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _decide(l, approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
          if (l.isWaitingForOther)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Waiting for them to respond',
                style: TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
