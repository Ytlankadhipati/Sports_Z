import 'package:sports_z/features/m4_common/counterpart.dart';

class CoachLinkItem {
  const CoachLinkItem({
    required this.id,
    required this.status,
    required this.sportId,
    required this.initiatedByMe,
    required this.myRole,
    required this.counterpart,
    this.createdAt,
    this.endedAt,
  });

  final String id;
  final String status; // requested | active | declined | ended
  final String sportId;
  final bool initiatedByMe;
  final String myRole; // coach | athlete
  final Counterpart counterpart;
  final String? createdAt;
  final String? endedAt;

  /// Waiting for ME to approve or decline.
  bool get needsMyResponse => status == 'requested' && !initiatedByMe;

  /// I asked; waiting for the other person.
  bool get isWaitingForOther => status == 'requested' && initiatedByMe;

  bool get isActive => status == 'active';

  factory CoachLinkItem.fromJson(Map<String, dynamic> json) => CoachLinkItem(
    id: json['id'] as String,
    status: json['status'] as String? ?? 'requested',
    sportId: json['sport_id'] as String? ?? '',
    initiatedByMe: json['initiated_by_me'] as bool? ?? false,
    myRole: json['my_role'] as String? ?? 'athlete',
    counterpart: Counterpart.fromJson(
      Map<String, dynamic>.from(json['counterpart'] as Map? ?? const {}),
    ),
    createdAt: json['created_at'] as String?,
    endedAt: json['ended_at'] as String?,
  );
}
