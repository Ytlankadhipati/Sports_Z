"""M5 repository: the only module allowed to access M5-owned collections."""
from app.core.database import db
from pymongo import ASCENDING, DESCENDING
from datetime import datetime, timezone

performance_entries = db["performance_entries"]
metric_bests = db["metric_bests"]
achievements = db["achievements"]
media = db["media"]
documents = db["documents"]
verification_requests = db["verification_requests"]

def ensure_indexes():
    performance_entries.create_index([("user_id", ASCENDING),("metric_key", ASCENDING),("recorded_at", DESCENDING)])
    performance_entries.create_index([("public_id", ASCENDING)], unique=True)
    metric_bests.create_index([("user_id", ASCENDING),("sport_id", ASCENDING),("metric_key", ASCENDING)], unique=True)
    achievements.create_index([("user_id", ASCENDING),("created_at", DESCENDING)])
    achievements.create_index([("public_id", ASCENDING)], unique=True)
    media.create_index([("user_id", ASCENDING),("created_at", DESCENDING)])
    media.create_index([("public_id", ASCENDING)], unique=True)
    documents.create_index([("user_id", ASCENDING),("created_at", DESCENDING)])
    documents.create_index([("public_id", ASCENDING)], unique=True)
    verification_requests.create_index([("user_id", ASCENDING),("status", ASCENDING)])
    verification_requests.create_index([("public_id", ASCENDING)], unique=True)

def utcnow(): return datetime.now(timezone.utc)

def find_asset_storage_key(kind: str, public_id: str, user_id: str):
    col = media if kind == "media" else documents
    doc = col.find_one({"public_id": public_id, "user_id": user_id}, {"storage_key": 1})
    return doc.get("storage_key") if doc else None
