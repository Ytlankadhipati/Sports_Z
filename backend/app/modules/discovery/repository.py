"""Only this module accesses the saved_items collection."""

import threading
from typing import Optional

from bson import ObjectId
from bson.errors import InvalidId
from pymongo.errors import DuplicateKeyError
from app.core.database import db

saved_items_collection = db["saved_items"]


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
        saved_items_collection.create_index(
            [("user_id", 1), ("type", 1), ("target_id", 1)],
            unique=True,
            name="uq_saved_user_type_target",
        )
        saved_items_collection.create_index(
            [("user_id", 1), ("_id", -1)], name="ix_saved_user_id"
        )
        _indexes_ready = True


def find_saved(user_id: str, type_: str, target_id: str) -> Optional[dict]:
    ensure_indexes()
    return saved_items_collection.find_one(
        {"user_id": user_id, "type": type_, "target_id": target_id}
    )


def upsert_saved(document: dict) -> dict:
    ensure_indexes()
    query = {
        "user_id": document["user_id"],
        "type": document["type"],
        "target_id": document["target_id"],
    }
    try:
        saved_items_collection.update_one(
            query,
            {"$setOnInsert": document},
            upsert=True,
        )
    except DuplicateKeyError:
        # A concurrent request inserted this same unique key first.
        pass
    return saved_items_collection.find_one(query)


def delete_saved(user_id: str, type_: str, target_id: str) -> None:
    ensure_indexes()
    saved_items_collection.delete_one(
        {"user_id": user_id, "type": type_, "target_id": target_id}
    )


def find_saved_page(
    user_id: str, type_: Optional[str], limit: int, cursor: Optional[str]
) -> list[dict]:
    ensure_indexes()
    query: dict = {"user_id": user_id}
    if type_:
        query["type"] = type_
    if cursor:
        try:
            query["_id"] = {"$lt": ObjectId(cursor)}
        except (InvalidId, TypeError) as exc:
            raise InvalidCursor("Invalid saved cursor") from exc
    return list(saved_items_collection.find(query).sort("_id", -1).limit(limit + 1))
