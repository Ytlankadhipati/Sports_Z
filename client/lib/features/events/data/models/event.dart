DateTime? _parseUtc(String? s) {
  if (s == null) return null;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
  return DateTime.tryParse(hasZone ? s : '${s}Z')?.toLocal();
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatEventDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

class SportEvent {
  final String publicId;
  final String title;
  final String sportId;
  final String location;
  final DateTime? startsAt;
  final DateTime? registrationDeadline;
  final int seatsLeft;
  final String status;

  const SportEvent({
    required this.publicId,
    required this.title,
    required this.sportId,
    required this.location,
    required this.startsAt,
    required this.registrationDeadline,
    required this.seatsLeft,
    required this.status,
  });

  bool get isFull => seatsLeft <= 0;

  factory SportEvent.fromJson(Map<String, dynamic> j) => SportEvent(
    publicId: j['public_id'] as String,
    title: j['title'] as String,
    sportId: j['sport_id'] as String,
    location: (j['location'] ?? '') as String,
    startsAt: _parseUtc(j['starts_at'] as String?),
    registrationDeadline: _parseUtc(j['registration_deadline'] as String?),
    seatsLeft: (j['seats_left'] ?? 0) as int,
    status: (j['status'] ?? 'upcoming') as String,
  );
}

class EventPage {
  final List<SportEvent> items;
  final String? nextCursor;
  const EventPage(this.items, this.nextCursor);
}