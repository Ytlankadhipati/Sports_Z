import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/messages/presentation/controllers/messages_controller.dart';
import 'package:sports_z/features/messages/presentation/screens/chat_screen.dart';

/// M05 New message: start a conversation with a first message.
/// Open it from a profile with [recipientUserId]. Without it a dev field is
/// shown so fixtures (scripts/seed_m4.py) can be used before profiles exist.
/// The server decides if you may message this person (ADR-001); a refusal is
/// shown as a message.
class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key, this.recipientUserId, this.recipientName});
  final String? recipientUserId;
  final String? recipientName;

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  static const _maxChars = 1000;
  final _text = TextEditingController();
  final _manualId = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _manualId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final recipient = widget.recipientUserId ?? _manualId.text.trim();
    final text = _text.text.trim();
    if (recipient.isEmpty || text.isEmpty) {
      m4Snack(context, 'Choose who to message and write something.');
      return;
    }
    setState(() => _sending = true);
    String? conversationId;
    final ok = await m4Run(context, () async {
      conversationId = await ref
          .read(messagesRepositoryProvider)
          .start(recipient, text);
    });
    if (!mounted) return;
    setState(() => _sending = false);
    final id = conversationId;
    if (ok && id != null) {
      ref.invalidate(conversationsProvider);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(conversationId: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.recipientName;
    return M4Page(
      title: 'New message',
      subtitle: name != null ? 'To $name' : null,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.recipientUserId == null) ...[
            TextField(
              controller: _manualId,
              style: const TextStyle(color: Colors.white),
              decoration: m4Input('User ID (dev)'),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _text,
            maxLength: _maxChars,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: m4Input('Message', hint: 'Write your message'),
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
                : const Text('Send'),
          ),
        ],
      ),
    );
  }
}
