import 'package:sports_z/features/m4_common/counterpart.dart';

class AccessGrantItem {
  const AccessGrantItem({
    required this.id,
    required this.status,
    required this.scopes,
    required this.role,
    required this.counterpart,
    this.source,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String status; // requested | active | declined | revoked
  final List<String> scopes;
  final String role; // owner (it is my data) | grantee (someone shared with me)
  final Counterpart counterpart;
  final String? source;
  final String? expiresAt;
  final String? createdAt;

  bool get iAmOwner => role == 'owner';

  /// Someone asked me for access and I have not answered yet.
  bool get needsMyDecision => iAmOwner && status == 'requested';

  bool get canRevoke => iAmOwner && (status == 'active' || status == 'requested');

  factory AccessGrantItem.fromJson(Map<String, dynamic> json) =>
      AccessGrantItem(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'requested',
        scopes: (json['scopes'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        role: json['role'] as String? ?? 'owner',
        counterpart: Counterpart.fromJson(
          Map<String, dynamic>.from(json['counterpart'] as Map? ?? const {}),
        ),
        source: json['source'] as String?,
        expiresAt: json['expires_at'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

/// Human wording for the scope ids the server accepts.
String scopeLabel(String scope) => switch (scope) {
  'profile_full' => 'Full profile',
  'physical' => 'Physical stats',
  'performance' => 'Performance',
  'certificates' => 'Certificates',
  'contact' => 'Contact details',
  _ => scope,
};
