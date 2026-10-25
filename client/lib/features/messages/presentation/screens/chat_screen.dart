import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/api_exception.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/messages/data/models/conversation_item.dart';
import 'package:sports_z/features/messages/data/models/message_item.dart';
import 'package:sports_z/features/messages/presentation/controllers/messages_controller.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

enum _SendState { sent, sending, failed }

/// One row in the chat. Server messages are `sent`; my not-yet-confirmed ones
/// are `sending` or `failed` (tap a failed one to retry).
class _ChatEntry {
  _ChatEntry({
    required this.key,
    required this.text,
    required this.mine,
    this.state = _SendState.sent,
  });
  final String key;
  final String text;
  final bool mine;
  _SendState state;
}

/// M03 Chat + M04 conversation actions (mute, delete for me).
/// States: loading, error, empty, sending, failed (retry), read-only banner.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _maxChars = 1000;

  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// Newest first (index 0 is the bottom of the screen: the list is reversed).
  final List<_ChatEntry> _entries = [];
  ConversationItem? _conversation;
  String? _nextCursor;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _tempCounter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  _ChatEntry _fromServer(MessageItem m) =>
      _ChatEntry(key: m.id, text: m.text, mine: m.senderIsMe);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(messagesRepositoryProvider);
      final page = await repo.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        // Keep my unconfirmed messages on top of the refreshed server list.
        final pending = _entries
            .where((e) => e.state != _SendState.sent)
            .toList();
        _entries
          ..clear()
          ..addAll(pending)
          ..addAll(page.messages.map(_fromServer));
        _conversation = page.conversation;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
      // Best effort; unread counts are private, nothing is shown to the other side.
      repo.markRead(widget.conversationId).catchError((Object _) {});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadOlder() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(messagesRepositoryProvider)
          .messages(widget.conversationId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.messages.map(_fromServer));
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      m4Snack(context, apiErrorText(error));
    }
  }

  Future<void> _send({_ChatEntry? retry}) async {
    final text = retry?.text ?? _input.text.trim();
    if (text.isEmpty) return;

    final entry =
        retry ??
        _ChatEntry(
          key: 'local-${_tempCounter++}',
          text: text,
          mine: true,
          state: _SendState.sending,
        );
    setState(() {
      if (retry == null) {
        _entries.insert(0, entry);
        _input.clear();
      } else {
        entry.state = _SendState.sending;
      }
    });

    try {
      final sent = await ref
          .read(messagesRepositoryProvider)
          .send(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        final index = _entries.indexWhere((e) => e.key == entry.key);
        if (index != -1) _entries[index] = _fromServer(sent);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => entry.state = _SendState.failed);
      m4Snack(context, apiErrorText(error));
      // The conversation may have become read-only (block, ended link).
      final status = apiExceptionFrom(error)?.statusCode;
      if (status == 403 || status == 404) _load();
    }
  }

  Future<void> _toggleMute() async {
    final c = _conversation;
    if (c == null) return;
    ConversationItem? updated;
    final ok = await m4Run(context, () async {
      updated = await ref
          .read(messagesRepositoryProvider)
          .setMuted(c.id, !c.muted);
    }, success: c.muted ? 'Unmuted' : 'Muted');
    if (ok && updated != null && mounted) {
      setState(() => _conversation = updated);
      ref.invalidate(conversationsProvider);
    }
  }

  Future<void> _deleteForMe() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'It is removed from your list only. The other person keeps their copy. '
          'A new message brings it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await m4Run(
      context,
      () => ref
          .read(messagesRepositoryProvider)
          .deleteForMe(widget.conversationId),
      success: 'Conversation deleted',
    );
    if (ok && mounted) {
      ref.invalidate(conversationsProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _conversation;
    return M4Page(
      title: c?.counterpart.displayName ?? 'Chat',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _loading ? null : _load,
        ),
        if (c != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'mute') _toggleMute();
              if (value == 'delete') _deleteForMe();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(c.muted ? 'Unmute' : 'Mute'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _conversation == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null && _conversation == null) {
      return M4Message(
        icon: Icons.error_outline,
        text: apiErrorText(_error!),
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final c = _conversation;
    final readOnly = c?.readOnly ?? false;
    return Column(
      children: [
        Expanded(
          child: _entries.isEmpty
              ? const M4Message(
                  icon: Icons.chat_bubble_outline,
                  text: 'No messages yet.',
                )
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  // +1 row at the end (= top) for the "load earlier" button.
                  itemCount: _entries.length + (_nextCursor != null ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _entries.length) {
                      return TextButton(
                        onPressed: _loadingMore ? null : _loadOlder,
                        child: Text(
                          _loadingMore ? 'Loading…' : 'Load earlier messages',
                          style: const TextStyle(color: AppColors.gold),
                        ),
                      );
                    }
                    return _bubble(_entries[i]);
                  },
                ),
        ),
        if (readOnly) _readOnlyBanner(c!) else _composer(),
      ],
    );
  }

  Widget _readOnlyBanner(ConversationItem c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    color: Colors.white.withValues(alpha: 0.06),
    child: Row(
      children: [
        const Icon(Icons.lock_outline, color: Colors.white54, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            c.readOnlyText,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    ),
  );

  Widget _composer() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              maxLength: _maxChars,
              style: const TextStyle(color: Colors.white),
              decoration: m4Input('Message').copyWith(counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );

  Widget _bubble(_ChatEntry e) {
    final failed = e.state == _SendState.failed;
    final sending = e.state == _SendState.sending;
    return Align(
      alignment: e.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: failed ? () => _send(retry: e) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: e.mine
                ? AppColors.mustard700.withValues(alpha: sending ? 0.5 : 1)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: failed ? Border.all(color: AppColors.error) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(e.text, style: const TextStyle(color: Colors.white)),
              if (sending)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Sending…',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              if (failed)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Failed. Tap to retry',
                    style: TextStyle(color: AppColors.error, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
