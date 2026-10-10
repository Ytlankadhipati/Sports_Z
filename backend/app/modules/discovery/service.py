from datetime import datetime, timezone
from typing import Optional

from app.modules.discovery import repository
from app.modules.events import service as events_service
from app.modules.opportunities import service as opportunities_service


class SavedActionError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


def _find_opportunity(target_id: str, _user_id: str):
    return opportunities_service.get_opportunity(target_id)


def _find_event(target_id: str, user_id: str):
    return events_service.get_event(target_id, user_id)


# Add a future saveable type here with its owning service and summary batch lookup.
_TARGET_SERVICES = {
    "opportunity": (_find_opportunity, opportunities_service.get_saved_summaries),
    "event": (_find_event, events_service.get_saved_summaries),
}


def is_saved(user_id: str, type_: str, target_id: str) -> bool:
    return repository.find_saved(user_id, type_, target_id) is not None


def _utc(value):
    if isinstance(value, datetime) and value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _check_target_exists(type_: str, target_id: str, user_id: str) -> None:
    target_services = _TARGET_SERVICES.get(type_)
    if target_services is None:
        raise SavedActionError(422, "INVALID_SAVED_TYPE", "Unsupported saved type")
    target = target_services[0](target_id, user_id)
    if target is None:
        raise SavedActionError(404, "NOT_FOUND", "Saved target not found")


def _format_item(row: dict, summaries: dict[tuple[str, str], dict]) -> dict:
    summary = summaries.get((row["type"], row["target_id"]))
    if summary is not None:
        summary = {key: _utc(value) for key, value in summary.items()}
    return {
        "type": row["type"],
        "target_id": row["target_id"],
        "saved_at": _utc(row["created_at"]),
        "available": summary is not None,
        "summary": summary,
    }


def save_item(user_id: str, type_: str, target_id: str) -> dict:
    _check_target_exists(type_, target_id, user_id)
    row = repository.upsert_saved(
        {
            "user_id": user_id,
            "type": type_,
            "target_id": target_id,
            "created_at": datetime.now(timezone.utc),
        }
    )
    summaries = {
        (type_, key): value
        for key, value in _TARGET_SERVICES[type_][1]([target_id]).items()
    }
    return _format_item(row, summaries)


def remove_item(user_id: str, type_: str, target_id: str) -> None:
    repository.delete_saved(user_id, type_, target_id)


def list_items(
    user_id: str, type_: Optional[str], limit: int, cursor: Optional[str]
) -> tuple[list[dict], Optional[str]]:
    rows = repository.find_saved_page(user_id, type_, limit, cursor)
    has_more = len(rows) > limit
    rows = rows[:limit]
    grouped: dict[str, list[str]] = {"opportunity": [], "event": []}
    for row in rows:
        if row["type"] in grouped:
            grouped[row["type"]].append(row["target_id"])

    summaries: dict[tuple[str, str], dict] = {}
    for type_name, target_ids in grouped.items():
        summaries.update(
            {
                (type_name, key): value
                for key, value in _TARGET_SERVICES[type_name][1](target_ids).items()
            }
        )

    next_cursor = str(rows[-1]["_id"]) if has_more and rows else None
    return [_format_item(row, summaries) for row in rows], next_cursor
