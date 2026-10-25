import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/privacy_access/data/models/access_grant_item.dart';
import 'package:sports_z/features/privacy_access/presentation/controllers/privacy_access_controller.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// PR07 Grant detail: scopes, expiry, and approve / decline / revoke (owner only).
class GrantDetailScreen extends ConsumerStatefulWidget {
  const GrantDetailScreen({super.key, required this.grant});
  final AccessGrantItem grant;

  @override
  ConsumerState<GrantDetailScreen> createState() => _GrantDetailScreenState();
}

class _GrantDetailScreenState extends ConsumerState<GrantDetailScreen> {
  late AccessGrantItem _grant = widget.grant;
  bool _busy = false;

  Future<void> _run(
    Future<AccessGrantItem> Function() action,
    String success,
  ) async {
    setState(() => _busy = true);
    AccessGrantItem? updated;
    final ok = await m4Run(context, () async {
      updated = await action();
    }, success: success);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok && updated != null) _grant = updated!;
    });
  }

  Future<void> _revoke() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          '${_grant.counterpart.displayName} will immediately lose this access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final repo = ref.read(privacyAccessRepositoryProvider);
    await _run(() => repo.revoke(_grant.id), 'Access revoked');
  }

  @override
  Widget build(BuildContext context) {
    final g = _grant;
    final repo = ref.read(privacyAccessRepositoryProvider);
    return M4Page(
      title: 'Access grant',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          M4Card(
            child: Row(
              children: [
                M4Avatar(g.counterpart, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.counterpart.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        g.iAmOwner
                            ? 'Asked to see your data'
                            : 'Shared with you',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                M4StatusChip(g.status),
              ],
            ),
          ),
          M4Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Access to',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scope in g.scopes)
                      Chip(
                        label: Text(scopeLabel(scope)),
                        backgroundColor: Colors.white12,
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _row('Expires', g.expiresAt ?? 'Not set yet'),
                if (g.source != null) _row('Source', g.source!),
              ],
            ),
          ),
          if (g.needsMyDecision)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => repo.approve(g.id), 'Access granted'),
                      style: m4PrimaryButton(),
                      child: const Text('Grant access'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => repo.decline(g.id),
                              'Request declined',
                            ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ),
          if (g.canRevoke && g.status == 'active')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton(
                onPressed: _busy ? null : _revoke,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Revoke access'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
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
