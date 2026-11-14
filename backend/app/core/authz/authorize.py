"""authorize(): decide allow / hidden(404) / forbidden(403). Pure function.

Rules (v3 doc):
  * Hidden resources answer EXACTLY like missing ones (404 NOT_FOUND) so a
    caller cannot learn that an id exists (no enumeration / IDOR leak).
  * 403 is only used when the resource is visible to the caller but the
    ACTION is not allowed (e.g. editing someone else's visible profile).
  * Block is checked first, in both directions.
  * Other members must NOT write their own authorize() logic.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

from app.core.authz import field_registry as fr
from app.core.authz.viewer_context import ViewerContext

Action = Literal["read", "write", "delete"]


@dataclass(frozen=True)
class Relationship:
    """Facts about viewer <-> resource owner. Filled by the caller from the
    relationship repositories (connections / coach_athlete_links / access_grants)."""

    blocked: bool = False                # blocked in EITHER direction
    connection_accepted: bool = False
    active_coach_link: bool = False      # viewer is the coach of an ACTIVE link
    grant_scopes: frozenset[str] = frozenset()


@dataclass(frozen=True)
class Resource:
    type: str                            # e.g. "athlete_profile", "conversation"
    owner_id: str | None = None
    participant_ids: frozenset[str] = frozenset()
    discoverable: bool = True            # athlete privacy.discoverable
    relationship: Relationship = field(default_factory=Relationship)


@dataclass(frozen=True)
class Decision:
    allowed: bool
    status: int            # 200, 403 or 404
    code: str              # OK | FORBIDDEN | NOT_FOUND
    reason: str = ""       # internal only, NEVER sent to the client


ALLOW = Decision(True, 200, "OK")
HIDDEN = Decision(False, 404, "NOT_FOUND")
FORBID = Decision(False, 403, "FORBIDDEN")

PARTICIPANT_ONLY = {"conversation", "message", "connection", "coach_link", "access_grant"}


def resolve_audiences(viewer: ViewerContext, resource: Resource) -> frozenset[str]:
    """Which registry audiences does this viewer belong to for this resource?"""
    if resource.owner_id is not None and viewer.user_id == resource.owner_id:
        return frozenset({fr.SELF})
    if viewer.is_admin:
        return frozenset({fr.ADMIN})

    rel = resource.relationship
    role = viewer.active_role
    if role == "coach":
        if not viewer.coach_verified:
            return frozenset({fr.ATHLETE_OTHER})  # unverified coach = ordinary user
        if rel.active_coach_link:
            return frozenset({fr.LINKED_COACH, fr.COACH})
        return frozenset({fr.COACH})
    if role == "recruiter":
        if not viewer.recruiter_verified:
            return frozenset({fr.ATHLETE_OTHER})
        return frozenset({fr.RECRUITER})
    if role == "athlete":
        return frozenset({fr.ATHLETE_OTHER})
    return frozenset()  # org / no active role: no profile audience


def authorize(viewer: ViewerContext, resource: Resource, action: Action = "read") -> Decision:
    # 0. platform-blocked users can do nothing
    if viewer.is_blocked_user:
        return FORBID if viewer.user_id == resource.owner_id else HIDDEN

    if viewer.active_role is None:
        return HIDDEN

    # 1. participant-only resources (conversation, link, grant ...)
    if resource.type in PARTICIPANT_ONLY:
        if viewer.is_admin and action == "read":
            return ALLOW
        if viewer.user_id in resource.participant_ids:
            return ALLOW
        return HIDDEN  # not a participant: indistinguishable from missing

    is_owner = resource.owner_id is not None and viewer.user_id == resource.owner_id

    # 2. owner always passes (own data is never block/privacy filtered)
    if is_owner:
        return ALLOW

    # 3. block, either direction -> hidden
    if resource.relationship.blocked:
        return HIDDEN

    # 4. admin
    if viewer.is_admin:
        return ALLOW if action == "read" else FORBID

    # 5. non-owner: only reads, and only if the owner is discoverable
    #    (a connection / active link lifts discoverability)
    rel = resource.relationship
    if not resource.discoverable and not (rel.connection_accepted or rel.active_coach_link):
        return HIDDEN
    if action != "read":
        return FORBID  # visible but not editable
    return ALLOW


def enforce(decision: Decision) -> None:
    """Raise the M1-style HTTP error for a denied decision (router helper)."""
    if decision.allowed:
        return
    from app.core.errors import forbidden, not_found  # lazy: keeps this module pure

    raise (forbidden() if decision.status == 403 else not_found())
