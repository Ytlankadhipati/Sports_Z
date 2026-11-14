import 'package:sports_z/features/m4_common/counterpart.dart';

class ConnectionItem {
  const ConnectionItem({
    required this.id,
    required this.status,
    required this.direction,
    required this.counterpart,
    required this.blockedByMe,
    this.note,
  });

  final String id;
  final String status; // requested | accepted | declined | blocked
  final String direction; // incoming | outgoing
  final Counterpart counterpart;
  final bool blockedByMe;
  final String? note;

  bool get isIncomingRequest => status == 'requested' && direction == 'incoming';
  bool get isSentRequest => status == 'requested' && direction == 'outgoing';

  factory ConnectionItem.fromJson(Map<String, dynamic> json) => ConnectionItem(
    id: json['id'] as String,
    status: json['status'] as String? ?? 'requested',
    direction: json['direction'] as String? ?? 'outgoing',
    counterpart: Counterpart.fromJson(
      Map<String, dynamic>.from(json['counterpart'] as Map? ?? const {}),
    ),
    blockedByMe: json['blocked_by_me'] as bool? ?? false,
    note: json['note'] as String?,
  );
}
