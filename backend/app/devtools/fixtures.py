"""Dev fixtures for M4 (S-13). Only used by the seed CLI and the Dev Counterpart Console.

Fixture users are real Mongo users (firebase_uid = "fixture-<name>") so they can be
related to a real signed-in tester. They have NO Firebase login: the console acts for them.
"""

from __future__ import annotations

from typing import Any

from bson import ObjectId

FIXTURES: dict[str, dict[str, Any]] = {
    "ATHLETE_1": {"role": "athlete", "name": "Fixture Athlete One", "verified": False},
    "ATHLETE_2": {"role": "athlete", "name": "Fixture Athlete Two", "verified": False},
    "COACH_V": {"role": "coach", "name": "Fixture Coach (verified)", "verified": True},
    "COACH_U": {"role": "coach", "name": "Fixture Coach (unverified)", "verified": False},
    "RECR_V": {"role": "recruiter", "name": "Fixture Recruiter (verified)", "verified": True},
    "RECR_U": {"role": "recruiter", "name": "Fixture Recruiter (unverified)", "verified": False},
    "ORG_V": {"role": "org", "name": "Fixture Organization", "verified": True},
    "ADMIN": {"role": "admin", "name": "Fixture Admin", "verified": True},
    "USER_BLOCKED": {"role": "athlete", "name": "Fixture Blocked User", "verified": False, "platform_blocked": True},
}


def fixture_uid(name: str) -> str:
    return f"fixture-{name}"


def seed_fixtures(users, profiles) -> dict[str, str]:
    """Idempotent. Returns {fixture_name: user_id}."""
    ids: dict[str, str] = {}
    for name, f in FIXTURES.items():
        doc = users.find_one({"firebase_uid": fixture_uid(name)})
        fields = {
            "role": f["role"],
            "full_name": f["name"],
            "verification_status": "verified" if f["verified"] else "unverified",
            "is_fixture": True,
            "platform_blocked": bool(f.get("platform_blocked")),
        }
        if doc is None:
            res = users.insert_one({"firebase_uid": fixture_uid(name), "email": None, **fields})
            user_id = str(res.inserted_id)
        else:
            users.update_one({"_id": doc["_id"]}, {"$set": fields})
            user_id = str(doc["_id"])
        ids[name] = user_id
        if f["role"] == "athlete":
            profiles.update_one(
                {"user_id": user_id},
                {"$set": {"full_name": f["name"], "city": "Pune", "sports": [{"sport_name": "Cricket"}],
                          "privacy": {"discoverable": True, "field_overrides": {}}},
                 "$setOnInsert": {"user_id": user_id}},
                upsert=True,
            )
    return ids


def reset_fixture_data(db, ids: dict[str, str]) -> dict[str, int]:
    """Delete M4 data that involves a fixture user. Never touches other users' data
    unless the other side is a fixture."""
    fixture_ids = list(ids.values())
    counts: dict[str, int] = {}
    conv_ids = [str(c["_id"]) for c in db["conversations"].find({"participants": {"$in": fixture_ids}}, {"_id": 1})]
    counts["messages"] = db["messages"].delete_many({"conversation_id": {"$in": conv_ids}}).deleted_count
    for coll in ("conversations", "connections", "coach_athlete_links", "access_grants"):
        counts[coll] = db[coll].delete_many({"participants": {"$in": fixture_ids}}).deleted_count
    return counts


def user_oid(user_id: str) -> ObjectId:
    return ObjectId(user_id)
