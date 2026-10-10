DateTime? _parseUtc(String? s) {
  if (s == null) return null;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
  return DateTime.tryParse(hasZone ? s : '${s}Z')?.toLocal();
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

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

class Opportunity {
  final String publicId;
  final String title;
  final String type;
  final String sportId;
  final String organizationName;
  final String location;
  final DateTime? deadline;
  final String status;

  const Opportunity({
    required this.publicId,
    required this.title,
    required this.type,
    required this.sportId,
    required this.organizationName,
    required this.location,
    required this.deadline,
    required this.status,
  });

  bool get isOpen => status == 'open';

  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(
    publicId: j['public_id'] as String,
    title: j['title'] as String,
    type: j['type'] as String,
    sportId: j['sport_id'] as String,
    organizationName: (j['organization_name'] ?? '') as String,
    location: (j['location'] ?? '') as String,
    deadline: _parseUtc(j['deadline'] as String?),
    status: (j['status'] ?? 'open') as String,
  );
}

/// GET /v1/opportunities/{public_id} ka response (OP02).
/// Summary ke saath description aur eligibility_summary bhi aate hain.
class OpportunityDetail {
  final Opportunity summary;
  final String description;
  final String eligibilitySummary;
  final bool isSaved;

  const OpportunityDetail({
    required this.summary,
    required this.description,
    required this.eligibilitySummary,
    this.isSaved = false,
  });

  factory OpportunityDetail.fromJson(Map<String, dynamic> j) =>
      OpportunityDetail(
        summary: Opportunity.fromJson(j),
        description: (j['description'] ?? '') as String,
        eligibilitySummary: (j['eligibility_summary'] ?? '') as String,
        isSaved: (j['is_saved'] ?? false) as bool,
      );
}

class OpportunityPage {
  final List<Opportunity> items;
  final String? nextCursor;
  const OpportunityPage(this.items, this.nextCursor);
}
