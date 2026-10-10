DateTime? _parseUtc(String? value) {
  if (value == null) return null;
  final hasZone =
      value.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
}

class SavedOpportunitySummary {
  const SavedOpportunitySummary({
    required this.title,
    required this.type,
    required this.sportId,
    required this.organizationName,
    required this.location,
    required this.deadline,
    required this.status,
  });

  final String title;
  final String type;
  final String sportId;
  final String organizationName;
  final String location;
  final DateTime? deadline;
  final String status;

  factory SavedOpportunitySummary.fromJson(Map<String, dynamic> json) =>
      SavedOpportunitySummary(
        title: json['title'] as String,
        type: json['type'] as String,
        sportId: json['sport_id'] as String,
        organizationName: (json['organization_name'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        deadline: _parseUtc(json['deadline'] as String?),
        status: json['status'] as String,
      );
}

class SavedEventSummary {
  const SavedEventSummary({
    required this.title,
    required this.sportId,
    required this.location,
    required this.startsAt,
    required this.status,
  });

  final String title;
  final String sportId;
  final String location;
  final DateTime? startsAt;
  final String status;

  factory SavedEventSummary.fromJson(Map<String, dynamic> json) =>
      SavedEventSummary(
        title: json['title'] as String,
        sportId: json['sport_id'] as String,
        location: (json['location'] ?? '') as String,
        startsAt: _parseUtc(json['starts_at'] as String?),
        status: json['status'] as String,
      );
}

class SavedItem {
  const SavedItem({
    required this.type,
    required this.targetId,
    required this.savedAt,
    required this.available,
    this.opportunity,
    this.event,
  });

  final String type;
  final String targetId;
  final DateTime? savedAt;
  final bool available;
  final SavedOpportunitySummary? opportunity;
  final SavedEventSummary? event;

  String get title => opportunity?.title ?? event?.title ?? 'Saved item';
  String get sportId => opportunity?.sportId ?? event?.sportId ?? '';
  String get location => opportunity?.location ?? event?.location ?? '';
  String get category => opportunity?.type ?? 'Event';

  factory SavedItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final rawSummary = json['summary'];
    final summary = rawSummary is Map<String, dynamic> ? rawSummary : null;
    return SavedItem(
      type: type,
      targetId: json['target_id'] as String,
      savedAt: _parseUtc(json['saved_at'] as String?),
      available: json['available'] as bool,
      opportunity: type == 'opportunity' && summary != null
          ? SavedOpportunitySummary.fromJson(summary)
          : null,
      event: type == 'event' && summary != null
          ? SavedEventSummary.fromJson(summary)
          : null,
    );
  }
}

class SavedPage {
  const SavedPage(this.items, this.nextCursor);

  final List<SavedItem> items;
  final String? nextCursor;
}
