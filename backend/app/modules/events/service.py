from datetime import datetime, timezone
from typing import Optional

from pymongo.errors import DuplicateKeyError

from app.modules.events import repository


class EventActionError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _summary(doc: dict, registration_state: str) -> dict:
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
        "registration_state": registration_state,
    }


def _detail(doc: dict, registration_state: str) -> dict:
    out = _summary(doc, registration_state)
    out["description"] = doc.get("description", "")
    out["capacity"] = doc.get("capacity", 0)
    return out


def list_events(
    sport_id: Optional[str],
    status: str,
    limit: int,
    cursor: Optional[str],
    user_id: str,
) -> tuple[list, Optional[str]]:
    filters: dict = {"status": status}
    if sport_id:
        filters["sport_id"] = sport_id

    rows = repository.find_event_page(filters, limit, cursor)
    has_more = len(rows) > limit
    rows = rows[:limit]
    states = repository.find_registration_states(
        user_id, [row["public_id"] for row in rows]
    )
    items = [
        _summary(row, states.get(row["public_id"], "not_registered"))
        for row in rows
    ]
    next_cursor = repository.encode_event_cursor(rows[-1]) if has_more and rows else None
    return items, next_cursor


def get_event(public_id: str, user_id: str, is_saved: bool = False) -> Optional[dict]:
    doc = repository.find_event_by_public_id(public_id)
    if doc is None:
        return None
    registration = repository.find_registration(public_id, user_id)
    state = registration.get("status") if registration else "not_registered"
    if state not in {"registered", "waitlisted"}:
        state = "not_registered"
    result = _detail(doc, state)
    result["is_saved"] = is_saved
    return result


def get_saved_summaries(public_ids: list[str]) -> dict[str, dict]:
    return {
        row["public_id"]: {
            "title": row["title"],
            "sport_id": row["sport_id"],
            "location": row.get("location", ""),
            "starts_at": row["starts_at"],
            "status": row.get("status", "upcoming"),
        }
        for row in repository.find_events_by_public_ids(public_ids)
    }


def _require_open_event(doc: Optional[dict], now: datetime) -> dict:
    if doc is None:
        raise EventActionError(404, "NOT_FOUND", "Event not found")
    deadline = doc.get("registration_deadline")
    if deadline is not None and _utc(deadline) <= now:
        raise EventActionError(
            409,
            "REGISTRATION_DEADLINE_PASSED",
            "The registration deadline has passed",
        )
    if doc.get("status") != "upcoming":
        raise EventActionError(
            409, "EVENT_CLOSED", "This event is not open for registration"
        )
    return doc


def register(public_id: str, user_id: str) -> dict:
    now = datetime.now(timezone.utc)
    event = _require_open_event(repository.find_event_by_public_id(public_id), now)

    # TODO(M3): EligibilityService check goes here (OP03).
    pending = {
        "event_id": public_id,
        "user_id": user_id,
        "status": "pending",
        "created_at": now,
    }
    try:
        repository.insert_pending_registration(pending)
    except DuplicateKeyError as exc:
        raise EventActionError(
            409, "DUPLICATE_REGISTRATION", "You already have an active registration"
        ) from exc

    counted_as: Optional[str] = None
    try:
        seat = repository.try_reserve_seat(public_id, now)
        if seat is not None:
            final_status = "registered"
            counted_as = "registered_count"
        else:
            if not repository.increment_waitlist(public_id, now):
                _require_open_event(
                    repository.find_event_by_public_id(public_id), now
                )
                raise EventActionError(
                    409,
                    "REGISTRATION_CHANGED",
                    "Event availability changed. Please try again",
                )
            final_status = "waitlisted"
            counted_as = "waitlist_count"

        if not repository.set_registration_status(
            public_id, user_id, "pending", final_status
        ):
            raise EventActionError(
                500, "REGISTRATION_FAILED", "Could not complete registration"
            )
    except Exception:
        if counted_as is not None:
            repository.adjust_event_counter(public_id, counted_as, -1)
        repository.delete_pending_registration(public_id, user_id)
        raise

    # TODO(M2): emit notification for registration confirmed after success.
    return {
        "event_public_id": public_id,
        "status": final_status,
        "created_at": now,
    }


def cancel_registration(public_id: str, user_id: str) -> None:
    if repository.find_event_by_public_id(public_id) is None:
        raise EventActionError(404, "NOT_FOUND", "Event not found")

    registration = repository.claim_cancellation(public_id, user_id)
    if registration is None:
        existing = repository.find_registration(public_id, user_id)
        if existing is not None and existing.get("status") == "cancelling":
            raise EventActionError(
                409,
                "CANCELLATION_IN_PROGRESS",
                "Your cancellation is already being processed",
            )
        raise EventActionError(
            404, "REGISTRATION_NOT_FOUND", "Active registration not found"
        )

    counter = (
        "registered_count"
        if registration["status"] == "registered"
        else "waitlist_count"
    )
    if not repository.adjust_event_counter(public_id, counter, -1):
        repository.restore_cancellation(registration)
        raise EventActionError(
            409, "REGISTRATION_COUNT_CONFLICT", "Registration count could not be updated"
        )
    if not repository.finish_cancellation(registration):
        repository.adjust_event_counter(public_id, counter, 1)
        repository.restore_cancellation(registration)
        raise EventActionError(
            409, "CANCELLATION_CONFLICT", "Registration could not be cancelled"
        )

    # TODO(M3): Promote the earliest waitlisted registration once seat promotion
    # can be made safe without a multi-document transaction.


def list_my_registrations(
    user_id: str, limit: int, cursor: Optional[str]
) -> tuple[list, Optional[str]]:
    rows = repository.find_my_registrations(user_id, limit, cursor)
    has_more = len(rows) > limit
    rows = rows[:limit]
    data = []
    for row in rows:
        event = row.get("event")
        if event is None:
            continue
        data.append(
            {
                "event_public_id": event["public_id"],
                "title": event["title"],
                "starts_at": event["starts_at"],
                "location": event.get("location", ""),
                "registration_status": row["status"],
                "created_at": row["created_at"],
            }
        )
    next_cursor = str(rows[-1]["_id"]) if has_more and rows else None
    return data, next_cursor
