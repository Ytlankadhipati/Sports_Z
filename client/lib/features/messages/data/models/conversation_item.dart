import 'package:sports_z/features/m4_common/counterpart.dart';

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.counterpart,
    required this.unreadCount,
    required this.muted,
    required this.readOnly,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.readOnlyReason,
  });

  final String id;
  final Counterpart counterpart;
  final String? lastMessagePreview;
  final String? lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool readOnly;
  final String? readOnlyReason; // blocked | basis_ended | pair_not_allowed

  /// Plain-language reason shown in the chat banner when [readOnly].
  String get readOnlyText => switch (readOnlyReason) {
    'basis_ended' =>
      'You are no longer connected, so you can only read this conversation.',
    'blocked' => 'This conversation is no longer available.',
    _ => 'This conversation is read-only.',
  };

  factory ConversationItem.fromJson(Map<String, dynamic> json) =>
      ConversationItem(
        id: json['id'] as String,
        counterpart: Counterpart.fromJson(
          Map<String, dynamic>.from(json['counterpart'] as Map? ?? const {}),
        ),
        lastMessagePreview: json['last_message_preview'] as String?,
        lastMessageAt: json['last_message_at'] as String?,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        muted: json['muted'] as bool? ?? false,
        readOnly: json['read_only'] as bool? ?? false,
        readOnlyReason: json['read_only_reason'] as String?,
      );
}
