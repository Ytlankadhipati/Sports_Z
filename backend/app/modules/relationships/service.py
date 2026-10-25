"""Connections, coach links and access grants. Pure business logic.

Services receive repositories + a user directory by injection, so unit tests
run on mongomock/in-memory fakes with no Firebase and no real Mongo.
Other members call these services (never the collections directly).
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Protocol

from app.core.authz import Relationship, ViewerContext
from app.core.platform_config import PlatformConfigService
from app.core.ratelimit import RateLimitExceeded, RateLimiter
from app.modules.relationships.errors import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    RateLimited,
    ValidationFailed,
)
from app.modules.relationships.repository import (
    AccessGrantRepository,
    CoachLinkRepository,
    ConnectionRepository,
    utcnow,
)

GRANT_SCOPES = frozenset({"profile_full", "physical", "performance", "certificates", "contact"})  # TODO(confirm)
ROLES_WITH_RELATIONSHIPS = {"athlete", "coach", "recruiter"}


class UserDirectory(Protocol):
    def get(self, user_id: str) -> dict[str, Any] | None: ...


def iso(dt: datetime | None) -> str | None:
    return dt.isoformat() + "Z" if dt else None


# ============================================================
# Relationship resolver (feeds authorize())
# ============================================================
class RelationshipResolver:
    def __init__(self, connections: ConnectionRepository, links: CoachLinkRepository,
                 grants: AccessGrantRepository, now=utcnow):
        self.connections, self.links, self.grants, self._now = connections, links, grants, now

    def is_blocked(self, a: str, b: str) -> bool:
        doc = self.connections.get_by_pair(a, b)
        return bool(doc and doc["status"] == "blocked")

    def connection_accepted(self, a: str, b: str) -> bool:
        doc = self.connections.get_by_pair(a, b)
        return bool(doc and doc["status"] == "accepted")

    def active_link(self, coach_id: str, athlete_id: str) -> bool:
        return self.links.find_active_between(coach_id, athlete_id) is not None

    def grant_scopes(self, owner_id: str, grantee_id: str) -> frozenset[str]:
        now, scopes = self._now(), set()
        for g in self.grants.active_between(owner_id, grantee_id):
            if g.get("expires_at") is None or g["expires_at"] > now:
                scopes.update(g.get("scopes", []))
        return frozenset(scopes)

    def relationship(self, viewer: ViewerContext, owner_id: str) -> Relationship:
        """Facts about viewer -> owner (athlete). Ending a link or blocking is
        reflected immediately because every call re-reads current state."""
        if viewer.user_id == owner_id:
            return Relationship()
        return Relationship(
            blocked=self.is_blocked(viewer.user_id, owner_id),
            connection_accepted=self.connection_accepted(viewer.user_id, owner_id),
            active_coach_link=(viewer.active_role == "coach"
                               and self.active_link(viewer.user_id, owner_id)),
            grant_scopes=self.grant_scopes(owner_id, viewer.user_id),
        )


def _check_role(viewer: ViewerContext) -> None:
    if viewer.active_role not in ROLES_WITH_RELATIONSHIPS:
        raise ForbiddenError("This role cannot use relationships")
    if viewer.is_blocked_user:
        raise ForbiddenError()


def _counterpart(directory: UserDirectory, user_id: str) -> dict[str, Any]:
    u = directory.get(user_id) or {}
    return {"user_id": user_id, "name": u.get("name"), "photo_url": u.get("photo_url"), "role": u.get("role")}


# ============================================================
# Connections (C01, C02, PR09)
# ============================================================
class ConnectionService:
    def __init__(self, repo: ConnectionRepository, directory: UserDirectory,
                 config: PlatformConfigService, limiter: RateLimiter):
        self.repo, self.directory, self.config, self.limiter = repo, directory, config, limiter

    def _view(self, doc: dict[str, Any], viewer_id: str) -> dict[str, Any]:
        other = next(p for p in doc["participants"] if p != viewer_id)
        return {
            "id": doc["id"], "status": doc["status"], "note": doc.get("note"),
            "direction": "outgoing" if doc["requester_id"] == viewer_id else "incoming",
            "counterpart": _counterpart(self.directory, other),
            "blocked_by_me": viewer_id in doc.get("blocked_by", []),
            "created_at": iso(doc["created_at"]), "updated_at": iso(doc["updated_at"]),
        }

    def _participant_doc(self, viewer: ViewerContext, conn_id: str) -> dict[str, Any]:
        doc = self.repo.get(conn_id)
        # non-participant == missing (IDOR safe)
        if doc is None or viewer.user_id not in doc["participants"]:
            raise NotFoundError()
        return doc

    def request(self, viewer: ViewerContext, target_id: str, note: str | None) -> dict[str, Any]:
        _check_role(viewer)
        if target_id == viewer.user_id:
            raise ValidationFailed("You cannot connect with yourself")
        max_note = self.config.get_int("limits.connection_note_max_chars", 140)
        note = (note or "").strip() or None
        if note and len(note) > max_note:
            raise ValidationFailed(f"Note must be at most {max_note} characters")
        target = self.directory.get(target_id)
        if target is None or target.get("role") not in ROLES_WITH_RELATIONSHIPS:
            raise NotFoundError()
        existing = self.repo.get_by_pair(viewer.user_id, target_id)
        if existing and existing["status"] == "blocked":
            raise NotFoundError()  # blocked either way: indistinguishable from missing
        if existing and existing["status"] in ("requested", "accepted"):
            raise ConflictError("A connection already exists")
        try:
            self.limiter.check(f"conn:{viewer.user_id}",
                               self.config.get_int("limits.connection_requests_per_day", 30), 86400)
        except RateLimitExceeded as e:
            raise RateLimited(e.retry_after)
        if existing:  # previously declined -> allow a new request
            self.repo.update(existing["id"], {
                "requester_id": viewer.user_id, "target_id": target_id,
                "status": "requested", "note": note})
            return self._view(self.repo.get(existing["id"]), viewer.user_id)
        return self._view(self.repo.insert(viewer.user_id, target_id, note), viewer.user_id)

    def respond(self, viewer: ViewerContext, conn_id: str, decision: str) -> dict[str, Any]:
        _check_role(viewer)
        doc = self._participant_doc(viewer, conn_id)
        if doc["target_id"] != viewer.user_id:
            raise ForbiddenError("Only the invited person can respond")
        if doc["status"] != "requested":
            raise ConflictError("This request was already handled")
        status = {"accept": "accepted", "decline": "declined"}.get(decision)
        if status is None:
            raise ValidationFailed("decision must be accept or decline")
        self.repo.update(conn_id, {"status": status})
        return self._view(self.repo.get(conn_id), viewer.user_id)

    def block(self, viewer: ViewerContext, target_id: str) -> dict[str, Any]:
        _check_role(viewer)
        if target_id == viewer.user_id:
            raise ValidationFailed("You cannot block yourself")
        if self.directory.get(target_id) is None:
            raise NotFoundError()
        doc = self.repo.get_by_pair(viewer.user_id, target_id)
        if doc is None:
            doc = self.repo.insert(viewer.user_id, target_id, None)
        blocked_by = sorted(set(doc.get("blocked_by", [])) | {viewer.user_id})
        self.repo.update(doc["id"], {"status": "blocked", "blocked_by": blocked_by})
        return self._view(self.repo.get(doc["id"]), viewer.user_id)

    def block_by_connection(self, viewer: ViewerContext, conn_id: str) -> dict[str, Any]:
        doc = self._participant_doc(viewer, conn_id)
        other = next(p for p in doc["participants"] if p != viewer.user_id)
        return self.block(viewer, other)

    def unblock(self, viewer: ViewerContext, conn_id: str) -> None:
        _check_role(viewer)
        doc = self._participant_doc(viewer, conn_id)
        if doc["status"] != "blocked" or viewer.user_id not in doc.get("blocked_by", []):
            raise NotFoundError()
        remaining = [u for u in doc["blocked_by"] if u != viewer.user_id]
        if remaining:
            self.repo.update(conn_id, {"blocked_by": remaining})
        else:
            self.repo.delete(conn_id)  # clean slate after unblock

    def list(self, viewer: ViewerContext, statuses: list[str] | None, limit: int,
             after_id: str | None):
        _check_role(viewer)
        docs = self.repo.list_for_user(viewer.user_id, statuses, limit + 1, after_id)
        # a user blocked BY someone else must not learn about it
        docs = [d for d in docs
                if not (d["status"] == "blocked" and viewer.user_id not in d.get("blocked_by", []))]
        nxt = docs[limit - 1]["id"] if len(docs) > limit else None
        return [self._view(d, viewer.user_id) for d in docs[:limit]], nxt


# ============================================================
# Access grants (PR06, PR07) + service used by M3 / M5
# ============================================================
class AccessGrantService:
    def __init__(self, repo: AccessGrantRepository, directory: UserDirectory,
                 config: PlatformConfigService, resolver_blocked, now=utcnow):
        """resolver_blocked(a, b) -> bool"""
        self.repo, self.directory, self.config = repo, directory, config
        self._blocked, self._now = resolver_blocked, now

    def _view(self, g: dict[str, Any], viewer_id: str) -> dict[str, Any]:
        other = g["grantee_id"] if g["owner_id"] == viewer_id else g["owner_id"]
        return {
            "id": g["id"], "status": g["status"], "scopes": g["scopes"], "source": g.get("source"),
            "expires_at": iso(g.get("expires_at")),
            "role": "owner" if g["owner_id"] == viewer_id else "grantee",
            "counterpart": _counterpart(self.directory, other),
            "created_at": iso(g["created_at"]),
        }

    def _validate_scopes(self, scopes: list[str]) -> list[str]:
        scopes = sorted(set(scopes or []))
        if not scopes:
            raise ValidationFailed("At least one scope is required")
        bad = [s for s in scopes if s not in GRANT_SCOPES]
        if bad:
            raise ValidationFailed(f"Unknown scopes: {', '.join(bad)}")
        return scopes

    def _expiry(self, expires_at: datetime | None) -> datetime:
        now = self._now()
        if expires_at is None:
            return now + timedelta(days=self.config.get_int("limits.grant_default_days", 90))
        if expires_at.tzinfo is not None:
            from datetime import timezone
            expires_at = expires_at.astimezone(timezone.utc).replace(tzinfo=None)
        if expires_at <= now:
            raise ValidationFailed("expires_at must be in the future")
        return expires_at

    def _owned(self, viewer: ViewerContext, grant_id: str) -> dict[str, Any]:
        g = self.repo.get(grant_id)
        if g is None or viewer.user_id not in g["participants"]:
            raise NotFoundError()
        if g["owner_id"] != viewer.user_id:
            raise ForbiddenError("Only the data owner can do this")
        return g

    # -- S-10: someone asks an athlete for access
    def request_access(self, viewer: ViewerContext, owner_id: str, scopes: list[str]) -> dict[str, Any]:
        _check_role(viewer)
        scopes = self._validate_scopes(scopes)
        owner = self.directory.get(owner_id)
        if owner is None or owner_id == viewer.user_id or self._blocked(viewer.user_id, owner_id):
            raise NotFoundError()
        g = self.repo.insert({"owner_id": owner_id, "grantee_id": viewer.user_id, "scopes": scopes,
                              "status": "requested", "source": "request", "source_ref": None,
                              "expires_at": None})
        return self._view(g, viewer.user_id)

    # -- owner approves a request
    def grant(self, viewer: ViewerContext, grant_id: str, expires_at: datetime | None = None) -> dict[str, Any]:
        g = self._owned(viewer, grant_id)
        if g["status"] != "requested":
            raise ConflictError("This request was already handled")
        if self._blocked(g["owner_id"], g["grantee_id"]):
            raise NotFoundError()
        self.repo.update(grant_id, {"status": "active", "expires_at": self._expiry(expires_at)})
        return self._view(self.repo.get(grant_id), viewer.user_id)

    def decline(self, viewer: ViewerContext, grant_id: str) -> dict[str, Any]:
        g = self._owned(viewer, grant_id)
        if g["status"] != "requested":
            raise ConflictError("This request was already handled")
        self.repo.update(grant_id, {"status": "declined"})
        return self._view(self.repo.get(grant_id), viewer.user_id)

    # -- POST /access-grants : owner grants proactively
    def create_direct(self, viewer: ViewerContext, grantee_id: str, scopes: list[str],
                      expires_at: datetime | None = None) -> dict[str, Any]:
        _check_role(viewer)
        if grantee_id == viewer.user_id or self.directory.get(grantee_id) is None \
                or self._blocked(viewer.user_id, grantee_id):
            raise NotFoundError()
        g = self.issue(viewer.user_id, grantee_id, scopes, expires_at, source="manual")
        return self._view(g, viewer.user_id)

    def revoke(self, viewer: ViewerContext, grant_id: str) -> dict[str, Any]:
        g = self._owned(viewer, grant_id)
        if g["status"] not in ("active", "requested"):
            raise ConflictError("Nothing to revoke")
        self.repo.update(grant_id, {"status": "revoked", "revoked_at": self._now()})
        return self._view(self.repo.get(grant_id), viewer.user_id)

    def list(self, viewer: ViewerContext, as_role: str | None, statuses: list[str] | None,
             limit: int, after_id: str | None):
        _check_role(viewer)
        docs = self.repo.list_for_user(viewer.user_id, as_role, statuses, limit + 1, after_id)
        nxt = docs[limit - 1]["id"] if len(docs) > limit else None
        return [self._view(d, viewer.user_id) for d in docs[:limit]], nxt

    # ---- INTERNAL API for M3 (application scopes) and M5 (certificate share) ----
    def issue(self, owner_id: str, grantee_id: str, scopes: list[str],
              expires_at: datetime | None = None, *, source: str, source_ref: str | None = None) -> dict[str, Any]:
        return self.repo.insert({
            "owner_id": owner_id, "grantee_id": grantee_id, "scopes": self._validate_scopes(scopes),
            "status": "active", "source": source, "source_ref": source_ref,
            "expires_at": self._expiry(expires_at)})

    def revoke_by_source(self, source: str, source_ref: str) -> int:
        n = 0
        for g in self.repo.find_by_source(source, source_ref):
            self.repo.update(g["id"], {"status": "revoked", "revoked_at": self._now()})
            n += 1
        return n


# ============================================================
# Coach links (L01, L02)
# ============================================================
class CoachLinkService:
    def __init__(self, repo: CoachLinkRepository, directory: UserDirectory,
                 grants: AccessGrantService, resolver_blocked):
        self.repo, self.directory, self.grants, self._blocked = repo, directory, grants, resolver_blocked

    def _view(self, link: dict[str, Any], viewer_id: str) -> dict[str, Any]:
        other = link["athlete_id"] if link["coach_id"] == viewer_id else link["coach_id"]
        return {
            "id": link["id"], "status": link["status"], "sport_id": link["sport_id"],
            "initiated_by_me": link["initiated_by"] == viewer_id,
            "my_role": "coach" if link["coach_id"] == viewer_id else "athlete",
            "counterpart": _counterpart(self.directory, other),
            "created_at": iso(link["created_at"]), "ended_at": iso(link.get("ended_at")),
        }

    def _participant(self, viewer: ViewerContext, link_id: str) -> dict[str, Any]:
        link = self.repo.get(link_id)
        if link is None or viewer.user_id not in link["participants"]:
            raise NotFoundError()
        return link

    def request(self, viewer: ViewerContext, counterpart_id: str, sport_id: str) -> dict[str, Any]:
        """Coach asks an athlete (S-06) OR an athlete asks a coach (open item, supported)."""
        _check_role(viewer)
        other = self.directory.get(counterpart_id)
        if other is None or counterpart_id == viewer.user_id or self._blocked(viewer.user_id, counterpart_id):
            raise NotFoundError()
        if viewer.active_role == "coach" and other.get("role") == "athlete":
            coach_id, athlete_id, coach_verified = viewer.user_id, counterpart_id, viewer.coach_verified
        elif viewer.active_role == "athlete" and other.get("role") == "coach":
            coach_id, athlete_id, coach_verified = counterpart_id, viewer.user_id, bool(other.get("verified"))
        else:
            raise ForbiddenError("Coach links are between one athlete and one coach")
        if not coach_verified:
            raise ForbiddenError("Only verified coaches can link with athletes")
        sport_id = (sport_id or "").strip()
        if not sport_id:
            raise ValidationFailed("sport_id is required")
        if self.repo.find_open(coach_id, athlete_id, sport_id):
            raise ConflictError("A link for this sport already exists")
        try:
            link = self.repo.insert(coach_id, athlete_id, sport_id, initiated_by=viewer.user_id)
        except Exception as e:  # unique index backstop for races
            if "duplicate" in str(e).lower() or "E11000" in str(e):
                raise ConflictError("A link for this sport already exists")
            raise
        return self._view(link, viewer.user_id)

    def _decide(self, viewer: ViewerContext, link_id: str, status: str) -> dict[str, Any]:
        _check_role(viewer)
        link = self._participant(viewer, link_id)
        if link["initiated_by"] == viewer.user_id:
            raise ForbiddenError("The other person must respond to this request")
        if link["status"] != "requested":
            raise ConflictError("This request was already handled")
        if self._blocked(link["coach_id"], link["athlete_id"]):
            raise NotFoundError()
        fields: dict[str, Any] = {"status": status}
        unset = None
        if status == "declined":
            unset = ["open"]
        self.repo.update(link_id, fields, unset=unset)
        return self._view(self.repo.get(link_id), viewer.user_id)

    def approve(self, viewer: ViewerContext, link_id: str) -> dict[str, Any]:
        return self._decide(viewer, link_id, "active")

    def decline(self, viewer: ViewerContext, link_id: str) -> dict[str, Any]:
        return self._decide(viewer, link_id, "declined")

    def end(self, viewer: ViewerContext, link_id: str) -> dict[str, Any]:
        """Either side ends (or the requester cancels). Revokes LINKED access immediately."""
        _check_role(viewer)
        link = self._participant(viewer, link_id)
        if link["status"] not in ("active", "requested"):
            raise ConflictError("This link is already closed")
        self.repo.update(link_id, {"status": "ended", "ended_at": utcnow(), "ended_by": viewer.user_id},
                         unset=["open"])
        self.grants.revoke_by_source("link", link_id)
        return self._view(self.repo.get(link_id), viewer.user_id)

    def list(self, viewer: ViewerContext, statuses: list[str] | None, limit: int, after_id: str | None):
        _check_role(viewer)
        docs = self.repo.list_for_user(viewer.user_id, statuses, limit + 1, after_id)
        nxt = docs[limit - 1]["id"] if len(docs) > limit else None
        return [self._view(d, viewer.user_id) for d in docs[:limit]], nxt
