import 'package:dio/dio.dart';
import 'package:sports_z/features/m4_common/m4_http.dart';
import 'package:sports_z/features/messages/data/models/conversation_item.dart';
import 'package:sports_z/features/messages/data/models/message_item.dart';

/// One page of a conversation. Messages are newest first (as the API sends them).
class MessagePage {
  const MessagePage({
    required this.conversation,
    required this.messages,
    this.nextCursor,
  });
  final ConversationItem conversation;
  final List<MessageItem> messages;
  final String? nextCursor;
}

class MessagesRepository {
  MessagesRepository(this._dio);
  final Dio _dio;

  Future<List<ConversationItem>> conversations({String query = ''}) async {
    final q = query.trim();
    final response = await _dio.get<Object?>(
      '/conversations',
      queryParameters: {'limit': 50, if (q.isNotEmpty) 'q': q},
    );
    return dataList(response).map(ConversationItem.fromJson).toList();
  }

  /// M05: starts a conversation (or re-uses the existing one) with a first message.
  /// Returns the conversation id.
  Future<String> start(String recipientUserId, String text) async {
    final response = await _dio.post<Object?>(
      '/conversations',
      data: {'recipient_user_id': recipientUserId, 'text': text},
    );
    return dataMap(response)['conversation_id'] as String;
  }

  Future<MessagePage> messages(String conversationId, {String? cursor}) async {
    final response = await _dio.get<Object?>(
      '/conversations/${Uri.encodeComponent(conversationId)}/messages',
      queryParameters: {'limit': 30, 'cursor': ?cursor},
    );
    final data = dataMap(response);
    return MessagePage(
      conversation: ConversationItem.fromJson(
        Map<String, dynamic>.from(data['conversation'] as Map),
      ),
      messages: (data['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => MessageItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      nextCursor: nextCursorOf(response),
    );
  }

  Future<MessageItem> send(String conversationId, String text) async {
    final response = await _dio.post<Object?>(
      '/conversations/${Uri.encodeComponent(conversationId)}/messages',
      data: {'text': text},
    );
    return MessageItem.fromJson(
      Map<String, dynamic>.from(dataMap(response)['message'] as Map),
    );
  }

  Future<void> markRead(String conversationId) async {
    await _dio.post<Object?>(
      '/conversations/${Uri.encodeComponent(conversationId)}/read',
    );
  }

  Future<ConversationItem> setMuted(String conversationId, bool muted) async {
    final response = await _dio.patch<Object?>(
      '/conversations/${Uri.encodeComponent(conversationId)}/mute',
      data: {'muted': muted},
    );
    return ConversationItem.fromJson(dataMap(response));
  }

  /// Hides the conversation for me only; the other person keeps their copy.
  Future<void> deleteForMe(String conversationId) async {
    await _dio.delete<Object?>(
      '/conversations/${Uri.encodeComponent(conversationId)}',
    );
  }
}
