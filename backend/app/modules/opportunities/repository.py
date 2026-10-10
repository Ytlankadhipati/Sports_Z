"""Only this file touches the `opportunities` collection (M3 owns it)."""
from typing import List, Optional

from bson import ObjectId
from bson.errors import InvalidId

from app.core.database import db

opportunities_collection = db["opportunities"]


class InvalidCursor(ValueError):
    pass


def find_page(filters: dict, limit: int, cursor: Optional[str]) -> List[dict]:
    query = dict(filters)
    if cursor:
        try:
            query["_id"] = {"$gt": ObjectId(cursor)}
        except (InvalidId, TypeError):
            raise InvalidCursor("Invalid cursor")
    # ek extra row lete hain taaki pata chale next page hai ya nahi
    return list(opportunities_collection.find(query).sort("_id", 1).limit(limit + 1))


def find_by_public_id(public_id: str) -> Optional[dict]:
    return opportunities_collection.find_one({"public_id": public_id})


def find_by_public_ids(public_ids: list[str]) -> list[dict]:
    if not public_ids:
        return []
    return list(opportunities_collection.find({"public_id": {"$in": public_ids}}))


def upsert_seed_opportunity(document: dict) -> None:
    """Insert stable dev seed data without overwriting existing records."""
    opportunities_collection.update_one(
        {"public_id": document["public_id"]},
        {"$setOnInsert": document},
        upsert=True,
    )
