"""Privacy schema (PR01-PR05 read side) and View-as preview (PR08).

View-as MUST use the same project() the real viewers hit, so what the athlete
previews is exactly what that audience gets.
"""

from __future__ import annotations

from typing import Any, Mapping

from app.core.authz import Relationship, Resource, ViewerContext, project
from app.core.authz import field_registry as fr
from app.modules.relationships.errors import ValidationFailed

PREVIEW_AUDIENCES = ("athlete", "coach", "linked_coach", "recruiter", "public")
CONTACT_POLICIES = ("anyone_verified", "connections_only", "nobody")  # TODO(confirm) values


def privacy_schema() -> dict[str, Any]:
    """What the privacy screens may toggle. M1 persists the values (PATCH /me/profile/privacy)."""
    fields = []
    for name in sorted(fr.HIDEABLE_FIELDS["athlete_profile"]):
        aud = sorted(fr.allowed_audiences("athlete_profile", name) - {fr.SELF, fr.ADMIN})
        fields.append({"field": name, "hideable": True, "visible_to": aud})
    return {
        "discoverable": {"type": "boolean", "default": True},
        "contact_policy": {"type": "enum", "options": list(CONTACT_POLICIES), "default": None},
        "fields": fields,
        "preview_audiences": list(PREVIEW_AUDIENCES),
    }


def _preview_viewer(audience: str) -> tuple[ViewerContext | None, Relationship, bool]:
    if audience == "public":
        return None, Relationship(), True
    if audience == "athlete":
        return ViewerContext("preview", frozenset({"athlete"}), "athlete"), Relationship(), False
    if audience == "coach":
        return ViewerContext("preview", frozenset({"coach"}), "coach", coach_verified=True), Relationship(), False
    if audience == "linked_coach":
        return (ViewerContext("preview", frozenset({"coach"}), "coach", coach_verified=True),
                Relationship(active_coach_link=True), False)
    if audience == "recruiter":
        return ViewerContext("preview", frozenset({"recruiter"}), "recruiter", recruiter_verified=True), Relationship(), False
    raise ValidationFailed(f"as must be one of: {', '.join(PREVIEW_AUDIENCES)}")


def preview_profile(profile: Mapping[str, Any], owner_id: str, audience: str) -> dict[str, Any]:
    viewer, rel, public = _preview_viewer(audience)
    resource = Resource(type="athlete_profile", owner_id=owner_id, relationship=rel)
    return project(viewer, profile, resource, public=public)
