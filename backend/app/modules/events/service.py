from typing import Optional, Tuple

from app.modules.events import repository


def _summary(doc: dict) -> dict:
    capacity = doc.get("capacity", 0)
    registered = doc.get("registered_count", 0)
    return {
        "public_id": doc["public_id"],
        "title": doc["title"],
        "sport_id": doc["sport_id"],
        "location": doc.get("location", ""),
        "starts_at": doc["starts_at"],
        "registration_deadline": doc.get("registration_deadline"),
        "seats_left": max(capacity - registered, 0),
        "status": doc.get("status", "upcoming"),
    }


def _detail(doc: dict) -> dict:
    out = _summary(doc)
    out["description"] = doc.get("description", "")
    out["capacity"] = doc.get("capacity", 0)
    return out


def list_events(
    sport_id: Optional[str], status: str, limit: int, cursor: Optional[str]
) -> Tuple[list, Optional[str]]:
    filters: dict = {"status": status}
    if sport_id:
        filters["sport_id"] = sport_id

    rows = repository.find_page(filters, limit, cursor)
    has_more = len(rows) > limit
    rows = rows[:limit]
    next_cursor = str(rows[-1]["_id"]) if has_more and rows else None
    return [_summary(r) for r in rows], next_cursor


def get_event(public_id: str) -> Optional[dict]:
    doc = repository.find_by_public_id(public_id)
    return _detail(doc) if doc else None