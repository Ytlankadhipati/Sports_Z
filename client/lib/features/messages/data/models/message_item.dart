class MessageItem {
  const MessageItem({
    required this.id,
    required this.text,
    required this.senderIsMe,
    this.createdAt,
  });

  final String id;
  final String text;
  final bool senderIsMe;
  final String? createdAt;

  factory MessageItem.fromJson(Map<String, dynamic> json) => MessageItem(
    id: json['id'] as String,
    text: json['text'] as String? ?? '',
    senderIsMe: json['sender_is_me'] as bool? ?? false,
    createdAt: json['created_at'] as String?,
  );
}
