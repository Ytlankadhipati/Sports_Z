import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/features/m4_common/m4_ui.dart';
import 'package:sports_z/features/messages/data/models/conversation_item.dart';
import 'package:sports_z/features/messages/presentation/controllers/messages_controller.dart';
import 'package:sports_z/features/messages/presentation/screens/chat_screen.dart';
import 'package:sports_z/features/messages/presentation/screens/new_message_screen.dart';
import 'package:sports_z/shared/theme/app_theme.dart';

/// M01 Conversations list, with M02 search (filters by name or last message).
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit(String value) => setState(() => _query = value.trim());

  void _clear() {
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _open(ConversationItem c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(conversationId: c.id)),
    );
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider(_query));
    return M4Page(
      title: 'Messages',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_square, color: AppColors.gold),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewMessageScreen()),
            );
            ref.invalidate(conversationsProvider);
          },
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              style: const TextStyle(color: Colors.white),
              decoration: m4Input('Search messages').copyWith(
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: m4Async<List<ConversationItem>>(
              conversations,
              onRetry: () => ref.invalidate(conversationsProvider),
              data: (items) {
                if (items.isEmpty) {
                  return M4Message(
                    icon: Icons.chat_bubble_outline,
                    text: _query.isEmpty
                        ? 'No conversations yet.'
                        : 'No results for "$_query".',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(conversationsProvider(_query).future),
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

  Widget _tile(ConversationItem c) {
    final unread = c.unreadCount > 0 && !c.muted;
    return M4Card(
      onTap: () => _open(c),
      child: Row(
        children: [
          M4Avatar(c.counterpart),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.counterpart.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (c.muted)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.notifications_off,
                          size: 14,
                          color: Colors.white38,
                        ),
                      ),
                    if (c.readOnly)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.lock, size: 14, color: Colors.white38),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.lastMessagePreview ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          if (unread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${c.unreadCount}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
