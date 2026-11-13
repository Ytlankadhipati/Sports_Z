/// One profile field the athlete may hide (from GET /me/privacy/schema).
class PrivacyField {
  const PrivacyField({required this.field, required this.visibleTo});
  final String field;
  final List<String> visibleTo;

  factory PrivacyField.fromJson(Map<String, dynamic> json) => PrivacyField(
    field: json['field'] as String? ?? '',
    visibleTo: (json['visible_to'] as List? ?? const [])
        .whereType<String>()
        .toList(),
  );
}

class PrivacySchema {
  const PrivacySchema({
    required this.contactPolicyOptions,
    required this.fields,
    required this.previewAudiences,
  });

  final List<String> contactPolicyOptions;
  final List<PrivacyField> fields;
  final List<String> previewAudiences;

  factory PrivacySchema.fromJson(Map<String, dynamic> json) {
    final contact = json['contact_policy'];
    return PrivacySchema(
      contactPolicyOptions: contact is Map
          ? (contact['options'] as List? ?? const [])
                .whereType<String>()
                .toList()
          : const [],
      fields: (json['fields'] as List? ?? const [])
          .whereType<Map>()
          .map((f) => PrivacyField.fromJson(Map<String, dynamic>.from(f)))
          .toList(),
      previewAudiences: (json['preview_audiences'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// The athlete's saved settings (stored by M1 under profile.privacy).
class PrivacySettingsValue {
  const PrivacySettingsValue({
    this.discoverable = true,
    this.contactPolicy,
    this.hiddenFields = const {},
  });

  final bool discoverable;
  final String? contactPolicy;
  final Set<String> hiddenFields;

  PrivacySettingsValue copyWith({
    bool? discoverable,
    String? contactPolicy,
    bool clearContactPolicy = false,
    Set<String>? hiddenFields,
  }) => PrivacySettingsValue(
    discoverable: discoverable ?? this.discoverable,
    contactPolicy: clearContactPolicy
        ? null
        : (contactPolicy ?? this.contactPolicy),
    hiddenFields: hiddenFields ?? this.hiddenFields,
  );

  factory PrivacySettingsValue.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PrivacySettingsValue();
    final overrides = json['field_overrides'];
    final hidden = <String>{};
    if (overrides is Map) {
      overrides.forEach((key, value) {
        if (value == 'hidden' && key is String) hidden.add(key);
      });
    }
    return PrivacySettingsValue(
      discoverable: json['discoverable'] as bool? ?? true,
      contactPolicy: json['contact_policy'] as String?,
      hiddenFields: hidden,
    );
  }

  /// Body for PATCH /me/profile/athlete  {"privacy": ...}
  Map<String, dynamic> toJson() => {
    'discoverable': discoverable,
    'contact_policy': contactPolicy,
    'field_overrides': {for (final f in hiddenFields) f: 'hidden'},
  };
}

String audienceLabel(String audience) => switch (audience) {
  'athlete' => 'Another athlete',
  'coach' => 'A coach (not linked)',
  'linked_coach' => 'Your linked coach',
  'recruiter' => 'A recruiter',
  'public' => 'Public ID page',
  _ => audience,
};

String contactPolicyLabel(String policy) => switch (policy) {
  'anyone_verified' => 'Any verified coach or recruiter',
  'connections_only' => 'Connections only',
  'nobody' => 'Nobody',
  _ => policy,
};

String fieldLabel(String field) => switch (field) {
  'bio' => 'About me',
  'city' => 'City',
  'region' => 'State / region',
  'experience' => 'Experience',
  'sport_profiles' => 'Sport details',
  'physical' => 'Physical stats',
  'photo_url' => 'Photo',
  _ => field,
};
