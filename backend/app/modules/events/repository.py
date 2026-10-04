"""Only this file touches the `events` collection (M3 owns it)."""
from typing import List, Optional

from bson import ObjectId
from bson.errors import InvalidId

from app.core.database import db

events_collection = db["events"]


class InvalidCursor(ValueError):
    pass


def find_page(filters: dict, limit: int, cursor: Optional[str]) -> List[dict]:
    query = dict(filters)
    if cursor:
        try:
            query["_id"] = {"$gt": ObjectId(cursor)}
        except (InvalidId, TypeError):
            raise InvalidCursor("Invalid cursor")
    return list(events_collection.find(query).sort("_id", 1).limit(limit + 1))


def find_by_public_id(public_id: str) -> Optional[dict]:
    return events_collection.find_one({"public_id": public_id})