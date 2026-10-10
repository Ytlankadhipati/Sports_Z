from datetime import datetime, timedelta, timezone

import pytest
from bson import ObjectId
from pydantic import ValidationError

from app.modules.discovery import service
from app.modules.discovery.schemas import SavedCreateRequest
from app.modules.events import service as events_service
from app.modules.opportunities import service as opportunities_service

_get_event_detail = events_service.get_event
_get_opportunity_detail = opportunities_service.get_opportunity


class FakeSavedRepository:
    def __init__(self):
        self.rows = []

    def find_saved(self, user_id, type_, target_id):
        return next(
            (
                row
                for row in self.rows
                if row["user_id"] == user_id
                and row["type"] == type_
                and row["target_id"] == target_id
            ),
            None,
        )

    def upsert_saved(self, document):
        existing = self.find_saved(
            document["user_id"], document["type"], document["target_id"]
        )
        if existing:
            return existing
        row = {**document, "_id": ObjectId()}
        self.rows.append(row)
        return row

    def delete_saved(self, user_id, type_, target_id):
        self.rows = [
            row
            for row in self.rows
            if not (
                row["user_id"] == user_id
                and row["type"] == type_
                and row["target_id"] == target_id
            )
        ]

    def find_saved_page(self, user_id, type_, limit, cursor):
        rows = [row for row in self.rows if row["user_id"] == user_id]
        if type_:
            rows = [row for row in rows if row["type"] == type_]
        rows.sort(key=lambda row: row["_id"], reverse=True)
        if cursor:
            rows = [row for row in rows if row["_id"] < ObjectId(cursor)]
        return rows[: limit + 1]


@pytest.fixture
def saved_repo(monkeypatch):
    fake = FakeSavedRepository()
    opportunity = {
        "public_id": "opp-a",
        "title": "State Athletics Trials",
        "type": "trial",
        "sport_id": "athletics",
        "organization_name": "UP Athletics Association",
        "location": "Lucknow",
        "deadline": datetime.now(timezone.utc) + timedelta(days=5),
        "status": "open",
    }
    event = {
        "public_id": "evt-a",
        "title": "District Athletics Meet",
        "sport_id": "athletics",
        "location": "Lucknow",
        "starts_at": datetime.now(timezone.utc) + timedelta(days=10),
        "status": "upcoming",
    }
    targets = {"opportunity": {"opp-a": opportunity}, "event": {"evt-a": event}}
    monkeypatch.setattr(service, "repository", fake)
    monkeypatch.setattr(
        opportunities_service,
        "get_opportunity",
        lambda public_id, is_saved=False: targets["opportunity"].get(public_id),
    )
    monkeypatch.setattr(
        events_service,
        "get_event",
        lambda public_id, user_id, is_saved=False: targets["event"].get(public_id),
    )
    monkeypatch.setattr(
        service,
        "_TARGET_SERVICES",
        {
            "opportunity": (
                lambda key, _user: targets["opportunity"].get(key),
                lambda ids: {
                    key: {
                        name: value
                        for name, value in targets["opportunity"][key].items()
                        if name != "public_id"
                    }
                    for key in ids
                    if key in targets["opportunity"]
                },
            ),
            "event": (
                lambda key, _user: targets["event"].get(key),
                lambda ids: {
                    key: {
                        name: value
                        for name, value in targets["event"][key].items()
                        if name != "public_id"
                    }
                    for key in ids
                    if key in targets["event"]
                },
            ),
        },
    )
    return fake


def test_save_and_idempotent_resave(saved_repo):
    first = service.save_item("athlete-a", "opportunity", "opp-a")
    first_saved_at = saved_repo.rows[0]["created_at"]
    second = service.save_item("athlete-a", "opportunity", "opp-a")

    assert len(saved_repo.rows) == 1
    assert first == second
    assert saved_repo.rows[0]["created_at"] == first_saved_at


def test_invalid_type_is_rejected():
    with pytest.raises(ValidationError):
        SavedCreateRequest(type="athlete", target_id="someone")


def test_client_cannot_set_saved_item_owner_or_timestamps():
    with pytest.raises(ValidationError):
        SavedCreateRequest(
            type="event",
            target_id="evt-a",
            user_id="athlete-b",
            created_at=datetime.now(timezone.utc),
        )


def test_unknown_target_returns_404(saved_repo):
    with pytest.raises(service.SavedActionError) as error:
        service.save_item("athlete-a", "opportunity", "missing")
    assert error.value.status_code == 404


def test_unsave_is_idempotent(saved_repo):
    service.remove_item("athlete-a", "event", "evt-a")
    service.remove_item("athlete-a", "event", "evt-a")
    assert saved_repo.rows == []


def test_user_b_cannot_see_or_remove_user_a_saved_item(saved_repo):
    service.save_item("athlete-a", "opportunity", "opp-a")

    visible, _ = service.list_items("athlete-b", None, 20, None)
    service.remove_item("athlete-b", "opportunity", "opp-a")

    assert visible == []
    assert len(saved_repo.rows) == 1
    assert saved_repo.rows[0]["user_id"] == "athlete-a"


def test_list_filter_cursor_and_unavailable_target(saved_repo):
    service.save_item("athlete-a", "event", "evt-a")
    service.save_item("athlete-a", "opportunity", "opp-a")
    missing = saved_repo.upsert_saved(
        {
            "user_id": "athlete-a",
            "type": "event",
            "target_id": "deleted-event",
            "created_at": datetime.now(timezone.utc),
        }
    )

    first_page, cursor = service.list_items("athlete-a", None, 1, None)
    second_page, _ = service.list_items("athlete-a", None, 1, cursor)
    event_items, _ = service.list_items("athlete-a", "event", 20, None)

    assert cursor is not None
    assert len(first_page) == len(second_page) == 1
    deleted_item = next(item for item in event_items if item["target_id"] == missing["target_id"])
    assert deleted_item["available"] is False
    assert deleted_item["summary"] is None
    assert all(item["type"] == "event" for item in event_items)


def test_detail_saved_state_is_computed_for_each_supported_target(saved_repo, monkeypatch):
    opportunity = {
        "public_id": "opp-a",
        "title": "State Athletics Trials",
        "type": "trial",
        "sport_id": "athletics",
        "organization_name": "UP Athletics Association",
        "location": "Lucknow",
        "deadline": None,
        "status": "open",
    }
    event = {
        "public_id": "evt-a",
        "title": "District Athletics Meet",
        "sport_id": "athletics",
        "location": "Lucknow",
        "starts_at": datetime.now(timezone.utc),
        "capacity": 10,
        "registered_count": 0,
        "status": "upcoming",
    }
    monkeypatch.setattr(
        opportunities_service.repository, "find_by_public_id", lambda _: opportunity
    )
    monkeypatch.setattr(
        events_service.repository, "find_event_by_public_id", lambda _: event
    )
    monkeypatch.setattr(events_service.repository, "find_registration", lambda *_: None)
    service.save_item("athlete-a", "opportunity", "opp-a")
    service.save_item("athlete-a", "event", "evt-a")

    opportunity_detail = _get_opportunity_detail(
        "opp-a", service.is_saved("athlete-a", "opportunity", "opp-a")
    )
    event_detail = _get_event_detail(
        "evt-a", "athlete-a", service.is_saved("athlete-a", "event", "evt-a")
    )

    assert opportunity_detail["is_saved"] is True
    assert event_detail["is_saved"] is True
    assert service.is_saved("athlete-b", "event", "evt-a") is False


def test_saved_routes_require_authentication(monkeypatch):
    from fastapi.testclient import TestClient

    from main import app

    response = TestClient(app).get("/v1/saved")
    assert response.status_code == 401
