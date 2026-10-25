import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/connections/presentation/controllers/connections_controller.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';

/// C01 Connect: send a connection request (note <= 140 chars).
/// Open from a profile with [targetUserId]. Without it a dev field is shown
/// so fixtures (see scripts/seed_m4.py) can be used before the profile screen exists.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key, this.targetUserId, this.targetName});
  final String? targetUserId;
  final String? targetName;

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  static const _maxNote = 140;
  final _note = TextEditingController();
  final _manualId = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    _manualId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final target = widget.targetUserId ?? _manualId.text.trim();
    if (target.isEmpty) {
      m4Snack(context, 'Enter who you want to connect with.');
      return;
    }
    setState(() => _sending = true);
    final ok = await m4Run(
      context,
      () => ref
          .read(connectionsRepositoryProvider)
          .request(target, note: _note.text)
          .then((_) {}),
      success: 'Connection request sent',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      ref.invalidate(connectionsProvider);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.targetName;
    return M4Page(
      title: 'Connect',
      subtitle: name != null ? 'Send a request to $name' : null,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.targetUserId == null) ...[
            TextField(
              controller: _manualId,
              style: const TextStyle(color: Colors.white),
              decoration: m4Input('User ID (dev)'),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _note,
            maxLength: _maxNote,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: m4Input('Add a note (optional)', hint: 'Say hello'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            style: m4PrimaryButton(),
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send request'),
          ),
        ],
      ),
    );
  }
}
