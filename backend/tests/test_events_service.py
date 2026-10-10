from datetime import datetime, timedelta, timezone

import pytest
from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.modules.events import repository, service


def _event(*, capacity=1, registered_count=0, deadline=None):
    now = datetime.now(timezone.utc)
    return {
        "_id": ObjectId(),
        "public_id": "evt_test",
        "title": "Test Athletics Meet",
        "sport_id": "athletics",
        "description": "Test event",
        "location": "Lucknow",
        "starts_at": now + timedelta(days=10),
        "registration_deadline": deadline or now + timedelta(days=2),
        "capacity": capacity,
        "registered_count": registered_count,
        "waitlist_count": 0,
        "status": "upcoming",
    }


class FakeEventsRepository:
    def __init__(self, event):
        self.event = event
        self.registrations = {}

    def find_event_by_public_id(self, public_id):
        return self.event if self.event["public_id"] == public_id else None

    def insert_pending_registration(self, document):
        key = (document["event_id"], document["user_id"])
        if key in self.registrations:
            raise DuplicateKeyError("duplicate event/user registration")
        self.registrations[key] = {**document, "_id": ObjectId()}

    def try_reserve_seat(self, public_id, now):
        event = self.find_event_by_public_id(public_id)
        if (
            event is None
            or event["status"] != "upcoming"
            or event["registered_count"] >= event["capacity"]
            or event["registration_deadline"] <= now
        ):
            return None
        event["registered_count"] += 1
        return event

    def increment_waitlist(self, public_id, now):
        event = self.find_event_by_public_id(public_id)
        if event is None or event["registration_deadline"] <= now:
            return False
        event["waitlist_count"] += 1
        return True

    def set_registration_status(self, public_id, user_id, expected, status):
        row = self.registrations.get((public_id, user_id))
        if row is None or row["status"] != expected:
            return False
        row["status"] = status
        return True

    def delete_pending_registration(self, public_id, user_id):
        row = self.registrations.get((public_id, user_id))
        if row and row["status"] == "pending":
            self.registrations.pop((public_id, user_id))

    def adjust_event_counter(self, public_id, counter, delta):
        event = self.find_event_by_public_id(public_id)
        if event is None or (delta < 0 and event.get(counter, 0) <= 0):
            return False
        event[counter] = event.get(counter, 0) + delta
        return True

    def find_registration(self, public_id, user_id):
        return self.registrations.get((public_id, user_id))

    def claim_cancellation(self, public_id, user_id):
        row = self.find_registration(public_id, user_id)
        if row is None or row["status"] not in {"registered", "waitlisted"}:
            return None
        previous = dict(row)
        row["status"] = "cancelling"
        return previous

    def finish_cancellation(self, row):
        key = (row["event_id"], row["user_id"])
        current = self.registrations.get(key)
        if current is None or current["status"] != "cancelling":
            return False
        self.registrations.pop(key)
        return True

    def restore_cancellation(self, row):
        self.registrations[(row["event_id"], row["user_id"])] = row


@pytest.fixture
def fake_events(monkeypatch):
    fake = FakeEventsRepository(_event())
    monkeypatch.setattr(service, "repository", fake)
    return fake


def test_registration_takes_the_last_seat(fake_events):
    fake_events.event["registered_count"] = fake_events.event["capacity"] - 1

    result = service.register("evt_test", "athlete-a")

    assert result["status"] == "registered"
    assert fake_events.event["registered_count"] == fake_events.event["capacity"]


def test_full_event_places_athlete_on_waitlist(fake_events):
    fake_events.event["registered_count"] = fake_events.event["capacity"]

    result = service.register("evt_test", "athlete-a")

    assert result["status"] == "waitlisted"
    assert fake_events.event["waitlist_count"] == 1


def test_duplicate_registration_returns_conflict(fake_events):
    fake_events.registrations[("evt_test", "athlete-a")] = {
        "event_id": "evt_test",
        "user_id": "athlete-a",
        "status": "registered",
    }

    with pytest.raises(service.EventActionError) as error:
        service.register("evt_test", "athlete-a")

    assert error.value.status_code == 409
    assert error.value.code == "DUPLICATE_REGISTRATION"
    assert fake_events.event["registered_count"] == 0


def test_registration_after_deadline_is_rejected(fake_events):
    fake_events.event["registration_deadline"] = datetime.now(timezone.utc) - timedelta(seconds=1)

    with pytest.raises(service.EventActionError) as error:
        service.register("evt_test", "athlete-a")

    assert error.value.status_code == 409
    assert error.value.code == "REGISTRATION_DEADLINE_PASSED"
    assert fake_events.registrations == {}


def test_cancellation_decrements_count_and_deletes_record(fake_events):
    fake_events.event["registered_count"] = 1
    fake_events.registrations[("evt_test", "athlete-a")] = {
        "event_id": "evt_test",
        "user_id": "athlete-a",
        "status": "registered",
        "_id": ObjectId(),
    }

    service.cancel_registration("evt_test", "athlete-a")

    assert fake_events.event["registered_count"] == 0
    assert fake_events.find_registration("evt_test", "athlete-a") is None


def test_an_athlete_cannot_cancel_another_users_registration(fake_events):
    fake_events.event["registered_count"] = 1
    victim = {
        "event_id": "evt_test",
        "user_id": "athlete-a",
        "status": "registered",
        "_id": ObjectId(),
    }
    fake_events.registrations[("evt_test", "athlete-a")] = victim

    with pytest.raises(service.EventActionError) as error:
        service.cancel_registration("evt_test", "athlete-b")

    assert error.value.status_code == 404
    assert fake_events.event["registered_count"] == 1
    assert fake_events.find_registration("evt_test", "athlete-a") == victim


def test_event_cursor_round_trip_is_stable():
    event = _event()

    cursor = repository.encode_event_cursor(event)
    start, object_id = repository._decode_event_cursor(cursor)

    assert start == event["starts_at"]
    assert object_id == event["_id"]


def test_events_route_rejects_missing_authentication():
    from fastapi.testclient import TestClient

    from main import app

    response = TestClient(app).get("/v1/events")

    assert response.status_code == 401
