"""Mongo access for connections, coach links and access grants (M4 owns these).

Repositories take a collection so tests can pass a mongomock collection.
Datetimes are stored as NAIVE UTC (what pymongo returns by default).
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from bson import ObjectId


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def pair_key(a: str, b: str) -> str:
    return "|".join(sorted([a, b]))


def to_oid(value: str) -> ObjectId | None:
    try:
        return ObjectId(value)
    except Exception:
        return None


def out(doc: dict[str, Any] | None) -> dict[str, Any] | None:
    if doc is None:
        return None
    doc = dict(doc)
    doc["id"] = str(doc.pop("_id"))
    return doc


class _Base:
    def __init__(self, collection):
        self.c = collection

    def get(self, doc_id: str) -> dict[str, Any] | None:
        oid = to_oid(doc_id)
        if oid is None:
            return None
        return out(self.c.find_one({"_id": oid}))

    def update(self, doc_id: str, fields: dict[str, Any], unset: list[str] | None = None) -> None:
        op: dict[str, Any] = {"$set": {**fields, "updated_at": utcnow()}}
        if unset:
            op["$unset"] = {k: "" for k in unset}
        self.c.update_one({"_id": to_oid(doc_id)}, op)

    def delete(self, doc_id: str) -> None:
        self.c.delete_one({"_id": to_oid(doc_id)})

    def _insert(self, doc: dict[str, Any]) -> dict[str, Any]:
        now = utcnow()
        doc = {**doc, "created_at": now, "updated_at": now}
        res = self.c.insert_one(doc)
        doc["_id"] = res.inserted_id
        return out(doc)

    def _page(self, query: dict[str, Any], limit: int, after_id: str | None) -> list[dict[str, Any]]:
        if after_id:
            oid = to_oid(after_id)
            if oid is not None:
                query = {**query, "_id": {"$lt": oid}}
        return [out(d) for d in self.c.find(query).sort("_id", -1).limit(limit)]


class ConnectionRepository(_Base):
    """One document per unordered user pair (unique pair_key)."""

    def get_by_pair(self, a: str, b: str) -> dict[str, Any] | None:
        return out(self.c.find_one({"pair_key": pair_key(a, b)}))

    def insert(self, requester_id: str, target_id: str, note: str | None) -> dict[str, Any]:
        return self._insert({
            "pair_key": pair_key(requester_id, target_id),
            "participants": [requester_id, target_id],
            "requester_id": requester_id,
            "target_id": target_id,
            "status": "requested",
            "note": note,
            "blocked_by": [],
        })

    def list_for_user(self, user_id: str, statuses: list[str] | None, limit: int, after_id: str | None):
        q: dict[str, Any] = {"participants": user_id}
        if statuses:
            q["status"] = {"$in": statuses}
        return self._page(q, limit, after_id)

    def ensure_indexes(self) -> None:
        self.c.create_index([("pair_key", 1)], unique=True, name="uq_connections_pair")
        self.c.create_index([("participants", 1), ("status", 1)], name="ix_connections_participant_status")


class CoachLinkRepository(_Base):
    def find_open(self, coach_id: str, athlete_id: str, sport_id: str) -> dict[str, Any] | None:
        return out(self.c.find_one({
            "coach_id": coach_id, "athlete_id": athlete_id, "sport_id": sport_id, "open": True,
        }))

    def find_active_between(self, coach_id: str, athlete_id: str) -> dict[str, Any] | None:
        return out(self.c.find_one({"coach_id": coach_id, "athlete_id": athlete_id, "status": "active"}))

    def insert(self, coach_id: str, athlete_id: str, sport_id: str, initiated_by: str) -> dict[str, Any]:
        return self._insert({
            "coach_id": coach_id, "athlete_id": athlete_id, "sport_id": sport_id,
            "participants": [coach_id, athlete_id],
            "initiated_by": initiated_by, "status": "requested", "open": True,
        })

    def list_for_user(self, user_id: str, statuses: list[str] | None, limit: int, after_id: str | None):
        q: dict[str, Any] = {"participants": user_id}
        if statuses:
            q["status"] = {"$in": statuses}
        return self._page(q, limit, after_id)

    def ensure_indexes(self) -> None:
        # one requested/active link per coach + athlete + sport
        self.c.create_index(
            [("coach_id", 1), ("athlete_id", 1), ("sport_id", 1)],
            unique=True,
            partialFilterExpression={"open": {"$eq": True}},
            name="uq_coach_links_open",
        )
        self.c.create_index([("participants", 1), ("status", 1)], name="ix_coach_links_participant_status")


class AccessGrantRepository(_Base):
    def insert(self, doc: dict[str, Any]) -> dict[str, Any]:
        doc = {**doc, "participants": [doc["owner_id"], doc["grantee_id"]]}
        return self._insert(doc)

    def list_for_user(self, user_id: str, as_role: str | None, statuses: list[str] | None,
                      limit: int, after_id: str | None):
        if as_role == "owner":
            q: dict[str, Any] = {"owner_id": user_id}
        elif as_role == "grantee":
            q = {"grantee_id": user_id}
        else:
            q = {"participants": user_id}
        if statuses:
            q["status"] = {"$in": statuses}
        return self._page(q, limit, after_id)

    def active_between(self, owner_id: str, grantee_id: str) -> list[dict[str, Any]]:
        return [out(d) for d in self.c.find(
            {"owner_id": owner_id, "grantee_id": grantee_id, "status": "active"}
        )]

    def find_by_source(self, source: str, source_ref: str) -> list[dict[str, Any]]:
        return [out(d) for d in self.c.find({"source": source, "source_ref": source_ref, "status": "active"})]

    def ensure_indexes(self) -> None:
        self.c.create_index([("owner_id", 1), ("grantee_id", 1), ("status", 1)], name="ix_grants_pair_status")
        self.c.create_index([("participants", 1)], name="ix_grants_participant")
        self.c.create_index([("source", 1), ("source_ref", 1)], name="ix_grants_source")


class MongoUserDirectory:
    """Read-only lookup into M1's collections (users, athlete_profiles).

    Returns {user_id, role, verified, name, photo_url} or None.
    TODO(confirm, M5): where verification state lives. For now:
    users.verification_status == "verified" or users.verification.status == "verified".
    """

    def __init__(self, users_collection, profiles_collection):
        self.users = users_collection
        self.profiles = profiles_collection

    def get(self, user_id: str) -> dict[str, Any] | None:
        oid = to_oid(user_id)
        if oid is None:
            return None
        u = self.users.find_one({"_id": oid})
        if not u:
            return None
        verification = u.get("verification") or {}
        verified = u.get("verification_status") == "verified" or verification.get("status") == "verified"
        p = self.profiles.find_one({"user_id": user_id}) or {}
        return {
            "user_id": user_id,
            "role": u.get("role"),
            "verified": bool(verified),
            "name": p.get("full_name") or u.get("full_name") or u.get("name"),
            "photo_url": p.get("photo_url"),
            "discoverable": ((p.get("privacy") or {}).get("discoverable", True)),
        }
