/// The other person in a connection / link / grant / conversation.
class Counterpart {
  const Counterpart({
    required this.userId,
    this.name,
    this.photoUrl,
    this.role,
  });

  final String userId;
  final String? name;
  final String? photoUrl;
  final String? role;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : 'SportsZ user';

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '?';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  factory Counterpart.fromJson(Map<String, dynamic> json) => Counterpart(
    userId: json['user_id'] as String? ?? '',
    name: json['name'] as String?,
    photoUrl: json['photo_url'] as String?,
    role: json['role'] as String?,
  );
}
