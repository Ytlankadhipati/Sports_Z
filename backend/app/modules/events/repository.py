"""Only this file accesses the events and event_registrations collections."""

import base64
import json
import threading
from datetime import datetime
from typing import Optional

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument

from app.core.database import db

events_collection = db["events"]
registrations_collection = db["event_registrations"]


class InvalidCursor(ValueError):
    pass


_indexes_ready = False
_indexes_lock = threading.Lock()


def ensure_indexes() -> None:
    global _indexes_ready
    if _indexes_ready:
        return
    with _indexes_lock:
        if _indexes_ready:
            return
        events_collection.create_index(
            [("public_id", 1)], unique=True, name="public_id_1"
        )
        events_collection.create_index(
            [("status", 1), ("starts_at", 1), ("_id", 1)],
            name="ix_events_status_start_id",
        )
        registrations_collection.create_index(
            [("event_id", 1), ("user_id", 1)],
            unique=True,
            name="uq_event_registrations_event_user",
        )
        registrations_collection.create_index(
            [("user_id", 1), ("_id", -1)], name="ix_event_registrations_user_id"
        )
        registrations_collection.create_index(
            [("event_id", 1), ("status", 1), ("created_at", 1), ("_id", 1)],
            name="ix_event_registrations_waitlist",
        )
        _indexes_ready = True


def encode_event_cursor(doc: dict) -> str:
    payload = json.dumps(
        {"starts_at": doc["starts_at"].isoformat(), "id": str(doc["_id"])},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(payload).decode().rstrip("=")


def _decode_event_cursor(cursor: str) -> tuple[datetime, ObjectId]:
    try:
        payload = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4))
        value = json.loads(payload)
        start = datetime.fromisoformat(value["starts_at"])
        object_id = ObjectId(value["id"])
    except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
        raise InvalidCursor("Invalid event cursor") from exc
    return start, object_id


def find_event_page(filters: dict, limit: int, cursor: Optional[str]) -> list[dict]:
    ensure_indexes()
    query = dict(filters)
    if cursor:
        starts_at, object_id = _decode_event_cursor(cursor)
        query["$or"] = [
            {"starts_at": {"$gt": starts_at}},
            {"starts_at": starts_at, "_id": {"$gt": object_id}},
        ]
    return list(
        events_collection.find(query)
        .sort([("starts_at", 1), ("_id", 1)])
        .limit(limit + 1)
    )


def find_event_by_public_id(public_id: str) -> Optional[dict]:
    ensure_indexes()
    return events_collection.find_one({"public_id": public_id})


def find_events_by_public_ids(public_ids: list[str]) -> list[dict]:
    ensure_indexes()
    if not public_ids:
        return []
    return list(events_collection.find({"public_id": {"$in": public_ids}}))


def find_registration_states(user_id: str, event_ids: list[str]) -> dict[str, str]:
    ensure_indexes()
    if not event_ids:
        return {}
    rows = registrations_collection.find(
        {
            "user_id": user_id,
            "event_id": {"$in": event_ids},
            "status": {"$in": ["registered", "waitlisted"]},
        },
        {"event_id": 1, "status": 1},
    )
    return {row["event_id"]: row["status"] for row in rows}


def insert_pending_registration(document: dict) -> None:
    ensure_indexes()
    registrations_collection.insert_one(document)


def try_reserve_seat(public_id: str, now: datetime) -> Optional[dict]:
    ensure_indexes()
    return events_collection.find_one_and_update(
        {
            "public_id": public_id,
            "status": "upcoming",
            "$expr": {
                "$lt": [
                    {"$ifNull": ["$registered_count", 0]},
                    {"$ifNull": ["$capacity", 0]},
                ]
            },
            "$or": [
                {"registration_deadline": {"$exists": False}},
                {"registration_deadline": None},
                {"registration_deadline": {"$gt": now}},
            ],
        },
        {"$inc": {"registered_count": 1}},
        return_document=ReturnDocument.AFTER,
    )


def increment_waitlist(public_id: str, now: datetime) -> bool:
    result = events_collection.update_one(
        {
            "public_id": public_id,
            "status": "upcoming",
            "$or": [
                {"registration_deadline": {"$exists": False}},
                {"registration_deadline": None},
                {"registration_deadline": {"$gt": now}},
            ],
        },
        {"$inc": {"waitlist_count": 1}},
    )
    return result.modified_count == 1


def set_registration_status(
    public_id: str, user_id: str, expected: str, status: str
) -> bool:
    result = registrations_collection.update_one(
        {"event_id": public_id, "user_id": user_id, "status": expected},
        {"$set": {"status": status}},
    )
    return result.modified_count == 1


def delete_pending_registration(public_id: str, user_id: str) -> None:
    registrations_collection.delete_one(
        {"event_id": public_id, "user_id": user_id, "status": "pending"}
    )


def adjust_event_counter(public_id: str, counter: str, delta: int) -> bool:
    query: dict = {"public_id": public_id}
    if delta < 0:
        query[counter] = {"$gt": 0}
    result = events_collection.update_one(query, {"$inc": {counter: delta}})
    return result.modified_count == 1


def find_registration(public_id: str, user_id: str) -> Optional[dict]:
    ensure_indexes()
    return registrations_collection.find_one(
        {"event_id": public_id, "user_id": user_id}
    )


def claim_cancellation(public_id: str, user_id: str) -> Optional[dict]:
    ensure_indexes()
    row = registrations_collection.find_one(
        {
            "event_id": public_id,
            "user_id": user_id,
            "status": {"$in": ["registered", "waitlisted"]},
        }
    )
    if row is None:
        return None
    result = registrations_collection.update_one(
        {
            "_id": row["_id"],
            "status": row["status"],
            "user_id": user_id,
        },
        {"$set": {"status": "cancelling"}},
    )
    if result.modified_count != 1:
        return None
    return row


def finish_cancellation(row: dict) -> bool:
    result = registrations_collection.delete_one(
        {"_id": row["_id"], "user_id": row["user_id"], "status": "cancelling"}
    )
    return result.deleted_count == 1


def restore_cancellation(row: dict) -> None:
    registrations_collection.update_one(
        {"_id": row["_id"], "user_id": row["user_id"], "status": "cancelling"},
        {"$set": {"status": row["status"]}},
    )


def find_my_registrations(user_id: str, limit: int, cursor: Optional[str]) -> list[dict]:
    ensure_indexes()
    query: dict = {"user_id": user_id, "status": {"$in": ["registered", "waitlisted"]}}
    if cursor:
        try:
            query["_id"] = {"$lt": ObjectId(cursor)}
        except (InvalidId, TypeError) as exc:
            raise InvalidCursor("Invalid registration cursor") from exc
    rows = list(
        registrations_collection.find(query)
        .sort("_id", -1)
        .limit(limit + 1)
    )
    event_ids = [row["event_id"] for row in rows]
    events = {
        row["public_id"]: row
        for row in events_collection.find({"public_id": {"$in": event_ids}})
    }
    for row in rows:
        row["event"] = events.get(row["event_id"])
    return rows


def upsert_seed_event(event: dict) -> None:
    ensure_indexes()
    events_collection.update_one(
        {"public_id": event["public_id"]},
        {"$setOnInsert": event},
        upsert=True,
    )
