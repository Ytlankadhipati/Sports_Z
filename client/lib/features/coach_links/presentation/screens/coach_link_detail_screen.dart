import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/coach_links/data/models/coach_link_item.dart';
import 'package:sports_z/features/coach_links/presentation/controllers/coach_links_controller.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// L02 Coach link detail: who, which sport, status, and End link.
/// Ending a link removes the coach's LINKED access immediately.
class CoachLinkDetailScreen extends ConsumerStatefulWidget {
  const CoachLinkDetailScreen({super.key, required this.link});
  final CoachLinkItem link;

  @override
  ConsumerState<CoachLinkDetailScreen> createState() =>
      _CoachLinkDetailScreenState();
}

class _CoachLinkDetailScreenState extends ConsumerState<CoachLinkDetailScreen> {
  late CoachLinkItem _link = widget.link;
  bool _busy = false;

  Future<void> _end() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _link.isActive ? 'End this link?' : 'Cancel this request?',
        ),
        content: Text(
          _link.isActive
              ? '${_link.counterpart.displayName} will immediately lose the '
                    'extra access that comes with being your coach.'
              : 'The request will be withdrawn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    CoachLinkItem? updated;
    final ok = await m4Run(context, () async {
      updated = await ref.read(coachLinksRepositoryProvider).end(_link.id);
    }, success: 'Link ended');
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok && updated != null) _link = updated!;
    });
    if (ok) ref.invalidate(coachLinksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = _link;
    return M4Page(
      title: 'Coach link',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          M4Card(
            child: Row(
              children: [
                M4Avatar(l.counterpart, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.counterpart.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l.myRole == 'athlete'
                            ? 'Your coach'
                            : 'Athlete you coach',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                M4StatusChip(l.status),
              ],
            ),
          ),
          M4Card(
            child: Column(
              children: [
                _row('Sport', l.sportId),
                _row('Requested by', l.initiatedByMe ? 'You' : 'Them'),
                if (l.createdAt != null) _row('Created', l.createdAt!),
                if (l.endedAt != null) _row('Ended', l.endedAt!),
              ],
            ),
          ),
          if (l.isActive || l.status == 'requested')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton(
                onPressed: _busy ? null : _end,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l.isActive ? 'End link' : 'Cancel request'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
