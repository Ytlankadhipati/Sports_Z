DateTime? _parseUtc(String? value) {
  if (value == null) return null;
  final hasZone =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatEventDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

class SportEvent {
  const SportEvent({
    required this.publicId,
    required this.title,
    required this.sportId,
    required this.location,
    required this.startsAt,
    required this.registrationDeadline,
    required this.seatsLeft,
    required this.status,
    this.registrationState = 'not_registered',
  });

  final String publicId;
  final String title;
  final String sportId;
  final String location;
  final DateTime? startsAt;
  final DateTime? registrationDeadline;
  final int seatsLeft;
  final String status;
  final String registrationState;

  bool get isFull => seatsLeft <= 0;

  factory SportEvent.fromJson(Map<String, dynamic> json) => SportEvent(
    publicId: json['public_id'] as String,
    title: json['title'] as String,
    sportId: json['sport_id'] as String,
    location: (json['location'] ?? '') as String,
    startsAt: _parseUtc(json['starts_at'] as String?),
    registrationDeadline: _parseUtc(json['registration_deadline'] as String?),
    seatsLeft: (json['seats_left'] ?? 0) as int,
    status: (json['status'] ?? 'upcoming') as String,
    registrationState:
        (json['registration_state'] ?? 'not_registered') as String,
  );
}

class EventDetail {
  const EventDetail({
    required this.summary,
    required this.description,
    required this.capacity,
    this.isSaved = false,
  });

  final SportEvent summary;
  final String description;
  final int capacity;
  final bool isSaved;

  factory EventDetail.fromJson(Map<String, dynamic> json) => EventDetail(
    summary: SportEvent.fromJson(json),
    description: (json['description'] ?? '') as String,
    capacity: (json['capacity'] ?? 0) as int,
    isSaved: (json['is_saved'] ?? false) as bool,
  );
}

class EventRegistrationResult {
  const EventRegistrationResult({
    required this.eventPublicId,
    required this.status,
    required this.createdAt,
  });

  final String eventPublicId;
  final String status;
  final DateTime? createdAt;

  factory EventRegistrationResult.fromJson(Map<String, dynamic> json) =>
      EventRegistrationResult(
        eventPublicId: json['event_public_id'] as String,
        status: json['status'] as String,
        createdAt: _parseUtc(json['created_at'] as String?),
      );
}

class MyEventRegistration {
  const MyEventRegistration({
    required this.eventPublicId,
    required this.title,
    required this.startsAt,
    required this.location,
    required this.registrationStatus,
    required this.createdAt,
  });

  final String eventPublicId;
  final String title;
  final DateTime? startsAt;
  final String location;
  final String registrationStatus;
  final DateTime? createdAt;

  factory MyEventRegistration.fromJson(Map<String, dynamic> json) =>
      MyEventRegistration(
        eventPublicId: json['event_public_id'] as String,
        title: json['title'] as String,
        startsAt: _parseUtc(json['starts_at'] as String?),
        location: (json['location'] ?? '') as String,
        registrationStatus: json['registration_status'] as String,
        createdAt: _parseUtc(json['created_at'] as String?),
      );
}

class EventPage {
  const EventPage(this.items, this.nextCursor);

  final List<SportEvent> items;
  final String? nextCursor;
}

class MyEventRegistrationPage {
  const MyEventRegistrationPage(this.items, this.nextCursor);

  final List<MyEventRegistration> items;
  final String? nextCursor;
}
