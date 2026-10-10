from app.modules.identity.me_service import build_me_response, mask_email, mask_phone


def test_mask_email():
    assert mask_email("ravi.kumar@example.com") == "r\u2022\u2022\u2022@example.com"
    assert mask_email(None) is None
    assert mask_email("not-an-email") is None
    assert mask_email("@example.com") is None


def test_mask_phone_india():
    assert mask_phone("+919876543210") == "+91 98\u2022\u2022\u2022 \u2022\u2022210"


def test_mask_phone_never_leaks_middle_digits():
    out = mask_phone("+919876543210")
    assert "7654" not in out and "76543" not in out


def test_mask_phone_edge_cases():
    assert mask_phone(None) is None
    assert mask_phone("") is None
    assert mask_phone("123") is None
    assert mask_phone("1234567").endswith("567")


def _user(**over):
    base = {
        "user_id": "u1",
        "firebase_uid": "f1",
        "role": "athlete",
        "claims": {
            "email": "ravi.kumar@example.com",
            "email_verified": True,
            "phone_number": "+919876543210",
            "providers": ["email", "phone", "google.com"],
        },
    }
    base.update(over)
    return base


def test_build_response_never_contains_full_email_or_phone():
    resp = build_me_response(_user(), {"full_name": "Ravi Kumar"}, {"sportsz_id": "SZ-4K7M-91Q2-7"}, "req-1")
    dumped = resp.model_dump_json()
    assert "ravi.kumar@example.com" not in dumped
    assert "9876543210" not in dumped
    assert resp.data.full_name == "Ravi Kumar"
    assert resp.data.account_label == "SportsZ athlete account"
    assert resp.data.email_verified is True
    assert resp.data.phone_verified is True
    assert resp.data.linked_providers == ["email", "phone", "google.com"]
    assert resp.data.roles == ["athlete"]
    assert resp.data.sportsz_id == "SZ-4K7M-91Q2-7"
    assert resp.meta.request_id == "req-1"


def test_build_response_unassigned_role_and_missing_data():
    resp = build_me_response(_user(role=None, claims={}), None, None, None)
    assert resp.data.roles == []
    assert resp.data.account_label == "SportsZ account"
    assert resp.data.email_masked is None
    assert resp.data.phone_masked is None
    assert resp.data.phone_verified is False
    assert resp.data.full_name is None
    assert resp.data.sportsz_id is None