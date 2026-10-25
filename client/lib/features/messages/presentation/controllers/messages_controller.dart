import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_z/core/network/providers.dart';
import 'package:sports_z/features/messages/data/models/conversation_item.dart';
import 'package:sports_z/features/messages/data/repositories/messages_repository.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => MessagesRepository(ref.watch(dioProvider)),
);

/// M01 list (empty query) and M02 search (non-empty query).
final conversationsProvider = FutureProvider.autoDispose
    .family<List<ConversationItem>, String>(
      (ref, query) =>
          ref.watch(messagesRepositoryProvider).conversations(query: query),
    );
