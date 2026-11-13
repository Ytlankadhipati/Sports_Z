"""Field registry: which audience may see which field. DEFAULT DENY.

A field that is not listed here is NEVER returned by project().
To expose a new field, add it here (and add a test). Nobody else edits this.

NOTE: the audience lists below are a PROPOSAL derived from the v3 doc and
must be confirmed by the team (marked TODO(confirm) in docs/api/relationships.yaml).
"""

from __future__ import annotations

# Audiences (computed from viewer + relationship in authorize.resolve_audiences)
SELF = "self"
ADMIN = "admin"
LINKED_COACH = "linked_coach"      # coach with an ACTIVE coach link to this athlete
COACH = "coach"                    # any other verified coach
RECRUITER = "recruiter"
ATHLETE_OTHER = "athlete_other"    # another athlete
PUBLIC = "public"                  # public ID page whitelist (no login)

AUTHENTICATED = frozenset({SELF, ADMIN, LINKED_COACH, COACH, RECRUITER, ATHLETE_OTHER})
EVERYONE = AUTHENTICATED | {PUBLIC}
PRIVILEGED = frozenset({SELF, ADMIN})

# resource_type -> field -> set of audiences allowed to see it
FIELD_REGISTRY: dict[str, dict[str, frozenset[str]]] = {
    "athlete_profile": {
        # public whitelist (public ID page)
        "sportsz_id": EVERYONE,
        "full_name": EVERYONE,
        "photo_url": EVERYONE,
        "sports": EVERYONE,
        # any signed-in user
        "bio": AUTHENTICATED,
        "city": AUTHENTICATED,
        "region": AUTHENTICATED,
        "experience": AUTHENTICATED,
        "sport_profiles": AUTHENTICATED,
        # coach / recruiter relevant, not other athletes
        "physical": frozenset({SELF, ADMIN, LINKED_COACH, RECRUITER}),
        # sensitive: owner and admin only
        "date_of_birth": PRIVILEGED,
        "gender": PRIVILEGED,
        "user_id": PRIVILEGED,
        "privacy": PRIVILEGED,
    },
    # participants only; projection keeps the shape small
    "connection": {
        "id": PRIVILEGED | {LINKED_COACH, COACH, RECRUITER, ATHLETE_OTHER},
        "status": PRIVILEGED | {LINKED_COACH, COACH, RECRUITER, ATHLETE_OTHER},
        "note": PRIVILEGED | {LINKED_COACH, COACH, RECRUITER, ATHLETE_OTHER},
    },
}

# Fields an athlete may hide via privacy.field_overrides = {"bio": "hidden"}.
# Overrides can only RESTRICT (never widen) and never hide a field from SELF/ADMIN.
HIDEABLE_FIELDS: dict[str, frozenset[str]] = {
    "athlete_profile": frozenset(
        {"bio", "city", "region", "experience", "sport_profiles", "physical", "photo_url"}
    ),
}


def allowed_audiences(resource_type: str, field: str) -> frozenset[str]:
    """Unknown resource type or field -> empty set (deny)."""
    return FIELD_REGISTRY.get(resource_type, {}).get(field, frozenset())
