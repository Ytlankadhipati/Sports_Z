from typing import Optional, Tuple

from app.modules.opportunities import repository


def _summary(doc: dict) -> dict:
    return {
        "public_id": doc["public_id"],
        "title": doc["title"],
        "type": doc["type"],
        "sport_id": doc["sport_id"],
        "organization_name": doc.get("organization_name", ""),
        "location": doc.get("location", ""),
        "deadline": doc.get("deadline"),
        "status": doc.get("status", "open"),
    }


def _detail(doc: dict, is_saved: bool = False) -> dict:
    out = _summary(doc)
    out["description"] = doc.get("description", "")
    # Raw eligibility rules bahar nahi jaate, sirf padhne layak summary
    out["eligibility_summary"] = doc.get("eligibility_summary", "")
    out["is_saved"] = is_saved
    return out


def list_opportunities(
    sport_id: Optional[str], type_: Optional[str], status: str, limit: int, cursor: Optional[str]
) -> Tuple[list, Optional[str]]:
    filters: dict = {"status": status}
    if sport_id:
        filters["sport_id"] = sport_id
    if type_:
        filters["type"] = type_

    rows = repository.find_page(filters, limit, cursor)
    has_more = len(rows) > limit
    rows = rows[:limit]
    next_cursor = str(rows[-1]["_id"]) if has_more and rows else None
    return [_summary(r) for r in rows], next_cursor


def get_opportunity(public_id: str, is_saved: bool = False) -> Optional[dict]:
    doc = repository.find_by_public_id(public_id)
    return _detail(doc, is_saved) if doc else None


def get_saved_summaries(public_ids: list[str]) -> dict[str, dict]:
    return {
        row["public_id"]: {
            key: value
            for key, value in _summary(row).items()
            if key != "public_id"
        }
        for row in repository.find_by_public_ids(public_ids)
    }
