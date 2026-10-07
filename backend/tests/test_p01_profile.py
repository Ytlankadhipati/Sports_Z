import uuid
from datetime import date
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from pymongo.errors import PyMongoError
from pydantic import ValidationError

from main import app
from app.core.database import (
    users_collection,
    athlete_profiles_collection,
    sports_ids_collection,
    sports_collection,
    organizations_collection,
)
from app.modules.identity.profile_schema import (
    AthleteProfileResponse,
    PhysicalStats,
    SportProfile,
    ExperienceItem,
    PrivacySettings,
)

client = TestClient(app)


@pytest.fixture
def athlete_fixture():
    """
    Creates real MongoDB test records for an authenticated athlete
    and ensures clean removal after the test.
    """
    uid = f"test_athlete_uid_{uuid.uuid4().hex[:12]}"
    email = f"{uid}@sportsz.test"
    sport_id = f"test_sport_{uuid.uuid4().hex[:6]}"
    org_id = f"ORG-{uuid.uuid4().hex[:6]}"
    sportsz_id = f"SZ-{uuid.uuid4().hex[:4].upper()}-99X1"

    # 1. Seed master sport & organization
    sports_collection.insert_one({
        "sport_id": sport_id,
        "name": "Cricket",
        "config": {},
    })
    organizations_collection.insert_one({
        "public_id": org_id,
        "name": "National Sports Club",
    })

    # 2. Seed user with athlete role
    user_res = users_collection.insert_one({
        "firebase_uid": uid,
        "email": email,
        "role": "athlete",
    })
    user_id = str(user_res.inserted_id)

    # 3. Seed athlete profile
    athlete_profiles_collection.insert_one({
        "user_id": user_id,
        "full_name": "Arjun Sharma",
        "date_of_birth": "2002-05-15",
        "gender": "Male",
        "city": "Mumbai",
        "region": "Maharashtra",
        "bio": "Competitive all-rounder cricketer.",
        "photo_url": "https://cdn.sportsz.test/photos/arjun.jpg",
        "sports": [
            {
                "sport_id": sport_id,
                "is_primary": True,
                "positions": ["All-Rounder", "Middle-Order Batsman"],
                "level": "State Level",
                "attributes": {"batting_style": "Right-hand"},
            }
        ],
        "physical": {
            "height_cm": 178.5,
            "weight_kg": 72.0,
            "dominant_hand": "Right",
            "measured_at": "2026-09-01",
        },
        "experience": [
            {
                "id": "exp-1",
                "title": "Junior Captain",
                "organization_id": org_id,
                "started_year": 2021,
                "ended_year": 2024,
                "description": "Led state championship squad.",
            }
        ],
        "privacy": {
            "discoverable": True,
            "contact_policy": "coaches_only",
            "field_overrides": {},
        },
    })

    # 4. Seed sports_ids
    sports_ids_collection.insert_one({
        "user_id": user_id,
        "sportsz_id": sportsz_id,
    })

    fixture_data = {
        "uid": uid,
        "email": email,
        "user_id": user_id,
        "sport_id": sport_id,
        "org_id": org_id,
        "sportsz_id": sportsz_id,
    }

    yield fixture_data

    # Cleanup
    users_collection.delete_one({"_id": user_res.inserted_id})
    athlete_profiles_collection.delete_one({"user_id": user_id})
    sports_ids_collection.delete_one({"user_id": user_id})
    sports_collection.delete_one({"sport_id": sport_id})
    organizations_collection.delete_one({"public_id": org_id})


def mock_firebase_auth(uid: str, email: str = "test@sportsz.test"):
    return patch(
        "firebase_admin.auth.verify_id_token",
        return_value={"uid": uid, "email": email},
    )


# ============================================================
# TEST CASES
# ============================================================

def test_1_valid_authenticated_athlete_returns_200(athlete_fixture):
    """Case 1: Valid authenticated athlete -> 200 with standard SportsZ envelope."""
    uid = athlete_fixture["uid"]

    with mock_firebase_auth(uid):
        response = client.get(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer valid_firebase_token"},
        )

    assert response.status_code == 200
    json_data = response.json()

    # Envelope validation
    assert "data" in json_data
    assert "meta" in json_data
    assert json_data["meta"]["request_id"] is not None

    data = json_data["data"]
    assert data["user_id"] == athlete_fixture["user_id"]
    assert data["sportsz_id"] == athlete_fixture["sportsz_id"]
    assert data["full_name"] == "Arjun Sharma"
    assert data["city"] == "Mumbai"
    assert data["region"] == "Maharashtra"
    assert data["bio"] == "Competitive all-rounder cricketer."
    assert data["photo_url"] == "https://cdn.sportsz.test/photos/arjun.jpg"
    assert data["cover_photo_url"] is None  # Unsupported on backend, integration TODO

    # Resolved display data
    assert len(data["sports"]) == 1
    assert data["sports"][0]["sport_name"] == "Cricket"
    assert data["sports"][0]["is_primary"] is True

    # Physical stats
    assert data["physical"]["height_cm"] == 178.5
    assert data["physical"]["dominant_hand"] == "Right"

    # Resolved experience
    assert len(data["experience"]) == 1
    assert data["experience"][0]["organization_name"] == "National Sports Club"

    # Completion score
    assert data["completion"] > 0
    assert data["completion"] <= 100


def test_2_no_authorization_header_returns_401():
    """Case 2: No Authorization header -> 401 with standard error format."""
    response = client.get("/v1/me/profile/athlete")
    assert response.status_code == 401
    err = response.json()
    assert "error" in err
    assert err["error"]["code"] == "AUTH_REQUIRED"
    assert err["error"]["request_id"] is not None


def test_3_invalid_firebase_token_returns_401():
    """Case 3: Invalid Firebase token -> 401."""
    with patch(
        "firebase_admin.auth.verify_id_token",
        side_effect=Exception("Invalid token signature"),
    ):
        response = client.get(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer bad_signature_token"},
        )

    assert response.status_code == 401
    err = response.json()
    assert "error" in err
    assert err["error"]["code"] == "AUTH_REQUIRED"


def test_4_expired_firebase_token_returns_401():
    """Case 4: Expired Firebase token -> 401."""
    with patch(
        "firebase_admin.auth.verify_id_token",
        side_effect=Exception("Firebase token has expired"),
    ):
        response = client.get(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer expired_token"},
        )

    assert response.status_code == 401
    err = response.json()
    assert "error" in err
    assert err["error"]["code"] == "AUTH_REQUIRED"


def test_5_authenticated_non_athlete_returns_403():
    """Case 5: Authenticated non-athlete (e.g. coach/recruiter) -> 403."""
    coach_uid = f"coach_{uuid.uuid4().hex[:10]}"
    user_res = users_collection.insert_one({
        "firebase_uid": coach_uid,
        "email": "coach@sportsz.test",
        "role": "coach",
    })

    try:
        with mock_firebase_auth(coach_uid):
            response = client.get(
                "/v1/me/profile/athlete",
                headers={"Authorization": "Bearer coach_token"},
            )

        assert response.status_code == 403
        err = response.json()
        assert "error" in err
        assert err["error"]["code"] == "FORBIDDEN"
        assert "Athlete role is required" in err["error"]["message"]
    finally:
        users_collection.delete_one({"_id": user_res.inserted_id})


def test_6_athlete_profile_not_found_returns_404():
    """Case 6: Athlete user with no athlete_profiles record -> 404, does not silently create profile."""
    uid = f"athlete_noprofile_{uuid.uuid4().hex[:10]}"
    user_res = users_collection.insert_one({
        "firebase_uid": uid,
        "email": "noprofile@sportsz.test",
        "role": "athlete",
    })
    user_id = str(user_res.inserted_id)

    try:
        with mock_firebase_auth(uid):
            response = client.get(
                "/v1/me/profile/athlete",
                headers={"Authorization": "Bearer valid_token"},
            )

        assert response.status_code == 404
        err = response.json()
        assert "error" in err
        assert err["error"]["code"] == "NOT_FOUND"

        # Verify profile was NOT silently created
        found = athlete_profiles_collection.find_one({"user_id": user_id})
        assert found is None
    finally:
        users_collection.delete_one({"_id": user_res.inserted_id})


def test_7_invalid_request_data_returns_422():
    """Case 7: Invalid/unexpected request parameters -> 422 standard error format."""
    # When requesting an endpoint expecting specific validated parameters
    from fastapi import Request
    from fastapi.exceptions import RequestValidationError

    # Verify validation handler directly
    exc = RequestValidationError([{"loc": ["query", "page"], "msg": "Invalid", "type": "type_error"}])
    from app.core.errors import validation_exception_handler
    import asyncio

    req = Request({"type": "http", "method": "GET", "path": "/test", "headers": []})
    resp = asyncio.run(validation_exception_handler(req, exc))
    assert resp.status_code == 422
    import json
    data = json.loads(resp.body)
    assert data["error"]["code"] == "VALIDATION_ERROR"


def test_8_mongodb_failure_returns_safe_500_error(athlete_fixture):
    """Case 8: MongoDB failure -> safe server error without leaking internals."""
    uid = athlete_fixture["uid"]
    safe_client = TestClient(app, raise_server_exceptions=False)

    with mock_firebase_auth(uid):
        with patch.object(
            athlete_profiles_collection,
            "find_one",
            side_effect=PyMongoError("Database connection lost"),
        ):
            response = safe_client.get(
                "/v1/me/profile/athlete",
                headers={"Authorization": "Bearer valid_token"},
            )

    assert response.status_code == 500
    err = response.json()
    assert "error" in err
    assert err["error"]["code"] == "INTERNAL_SERVER_ERROR"
    assert "Database connection lost" not in err["error"]["message"]
    assert "pymongo" not in err["error"]["message"].lower()


def test_9_bola_security_user_a_cannot_access_user_b(athlete_fixture):
    """Case 9 & Case 22: User A cannot access User B through P01 (?user_id=B is ignored/rejected)."""
    uid_a = athlete_fixture["uid"]
    user_id_a = athlete_fixture["user_id"]

    # Create athlete B
    uid_b = f"athlete_b_{uuid.uuid4().hex[:10]}"
    user_b_res = users_collection.insert_one({
        "firebase_uid": uid_b,
        "email": "athlete_b@sportsz.test",
        "role": "athlete",
    })
    user_id_b = str(user_b_res.inserted_id)
    athlete_profiles_collection.insert_one({
        "user_id": user_id_b,
        "full_name": "Rohan Athlete B",
        "city": "Delhi",
    })

    try:
        # User A makes request attempting to pass user_id of B as query param
        with mock_firebase_auth(uid_a):
            response = client.get(
                f"/v1/me/profile/athlete?user_id={user_id_b}",
                headers={"Authorization": "Bearer token_a"},
            )

        assert response.status_code == 200
        data = response.json()["data"]

        # MUST return User A's profile ONLY
        assert data["user_id"] == user_id_a
        assert data["full_name"] == "Arjun Sharma"
        assert data["user_id"] != user_id_b
        assert data["full_name"] != "Rohan Athlete B"
    finally:
        users_collection.delete_one({"_id": user_b_res.inserted_id})
        athlete_profiles_collection.delete_one({"user_id": user_id_b})


def test_10_sportsz_id_is_not_client_controlled(athlete_fixture):
    """Case 10: SportsZ ID is server-owned and derived from sports_ids collection."""
    uid = athlete_fixture["uid"]
    expected_sportsz_id = athlete_fixture["sportsz_id"]

    with mock_firebase_auth(uid):
        response = client.get(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer valid_token"},
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["sportsz_id"] == expected_sportsz_id


def test_11_internal_mongodb_id_not_leaked(athlete_fixture):
    """Case 11: MongoDB _id is not present in response data."""
    uid = athlete_fixture["uid"]

    with mock_firebase_auth(uid):
        response = client.get(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer valid_token"},
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert "_id" not in data
    for item in data.get("sports", []):
        assert "_id" not in item
    for item in data.get("experience", []):
        assert "_id" not in item


def test_12_unexpected_fields_rejected_by_schema():
    """Case 12: Schemas reject unexpected fields (extra='forbid')."""
    with pytest.raises(ValidationError):
        AthleteProfileResponse(
            user_id="user-123",
            unexpected_field="hack",
        )

    with pytest.raises(ValidationError):
        PhysicalStats(
            height_cm=180,
            invalid_prop="injection",
        )

    with pytest.raises(ValidationError):
        SportProfile(
            sport_id="cricket",
            unknown_key="bar",
        )


def test_13_integration_complete_vertical_flow(athlete_fixture):
    """Case 13: Full vertical flow test from auth to response."""
    uid = athlete_fixture["uid"]
    user_id = athlete_fixture["user_id"]

    # 1. Firebase Auth verifies token and resolves SportsZ user
    with mock_firebase_auth(uid):
        response = client.get(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer valid_token"},
        )

    # 2. Status code 200
    assert response.status_code == 200

    # 3. Response validation
    body = response.json()
    assert body["data"]["user_id"] == user_id
    assert body["data"]["sportsz_id"] == athlete_fixture["sportsz_id"]
    assert body["meta"]["request_id"] is not None


def test_14_authenticated_onboarding_creates_profile_and_server_sports_id():
    uid = f"onboard_uid_{uuid.uuid4().hex[:12]}"
    user_res = users_collection.insert_one({
        "firebase_uid": uid,
        "email": f"{uid}@sportsz.test",
        "role": "athlete",
    })
    user_id = str(user_res.inserted_id)
    payload = {
        "full_name": "Test Athlete",
        "date_of_birth": "2004-03-14",
        "gender": "Other",
        "photo_url": None,
        "sports": [{
            "sport_name": "Cricket",
            "positions": ["All-Rounder"],
            "level": "District Level",
        }],
    }
    try:
        with mock_firebase_auth(uid):
            response = client.put(
                "/v1/me/profile/athlete",
                json=payload,
                headers={"Authorization": "Bearer valid_token"},
            )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["user_id"] == user_id
        assert data["sportsz_id"]
        assert data["full_name"] == "Test Athlete"
        assert data["sports"][0]["sport_name"] == "Cricket"
        assert athlete_profiles_collection.count_documents({"user_id": user_id}) == 1
        assert sports_ids_collection.count_documents({"user_id": user_id}) == 1
    finally:
        athlete_profiles_collection.delete_one({"user_id": user_id})
        sports_ids_collection.delete_one({"user_id": user_id})
        users_collection.delete_one({"_id": user_res.inserted_id})


def test_15_onboarding_update_is_idempotent_and_rejects_server_fields():
    uid = f"onboard_idempotent_{uuid.uuid4().hex[:10]}"
    user_res = users_collection.insert_one({
        "firebase_uid": uid,
        "email": f"{uid}@sportsz.test",
        "role": "athlete",
    })
    user_id = str(user_res.inserted_id)
    payload = {
        "full_name": "Test Athlete",
        "date_of_birth": "2004-03-14",
        "gender": "Other",
        "sports": [{"sport_name": "Badminton", "positions": ["Singles"]}],
    }
    headers = {"Authorization": "Bearer valid_token"}
    try:
        with mock_firebase_auth(uid):
            first = client.put("/v1/me/profile/athlete", json=payload, headers=headers)
            second = client.put("/v1/me/profile/athlete", json=payload, headers=headers)
            forged = client.put(
                "/v1/me/profile/athlete",
                json={**payload, "user_id": "another-user", "sportsz_id": "forged"},
                headers=headers,
            )
        assert first.status_code == second.status_code == 200
        assert first.json()["data"]["sportsz_id"] == second.json()["data"]["sportsz_id"]
        assert athlete_profiles_collection.count_documents({"user_id": user_id}) == 1
        assert sports_ids_collection.count_documents({"user_id": user_id}) == 1
        assert forged.status_code == 422
    finally:
        athlete_profiles_collection.delete_one({"user_id": user_id})
        sports_ids_collection.delete_one({"user_id": user_id})
        users_collection.delete_one({"_id": user_res.inserted_id})


def test_16_onboarding_patch_saves_sparse_sections(athlete_fixture):
    with mock_firebase_auth(athlete_fixture["uid"]):
        response = client.patch(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer valid_firebase_token"},
            json={
                "bio": "Updated intro",
                "physical": {"height_cm": 181},
                "sports": [{
                    "sport_id": athlete_fixture["sport_id"],
                    "sport_name": "Cricket",
                }],
            },
        )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["bio"] == "Updated intro"
    assert data["physical"]["height_cm"] == 181
    assert data["full_name"] == "Arjun Sharma"
    assert data["sports"][0]["sport_id"] == athlete_fixture["sport_id"]
    assert "_id" not in data


def test_17_onboarding_patch_rejects_server_owned_fields(athlete_fixture):
    with mock_firebase_auth(athlete_fixture["uid"]):
        response = client.patch(
            "/v1/me/profile/athlete",
            headers={"Authorization": "Bearer valid_firebase_token"},
            json={"sportsz_id": "SZ-CLIENT-1234"},
        )

    assert response.status_code == 422


def test_sports_catalog_and_config_use_existing_sports_collection(athlete_fixture):
    listing = client.get("/v1/sports")
    config = client.get(f"/v1/sports/{athlete_fixture['sport_id']}/config")

    assert listing.status_code == 200
    assert any(
        item["sport_id"] == athlete_fixture["sport_id"]
        for item in listing.json()["data"]["sports"]
    )
    assert config.status_code == 200
    assert config.json()["data"]["sport"]["sport_id"] == athlete_fixture["sport_id"]
    assert "_id" not in config.json()["data"]["sport"]
