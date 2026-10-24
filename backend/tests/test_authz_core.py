"""M4 authz core tests: pure logic, no DB, no Firebase."""

import pytest

from app.core.authz import (
    InvalidActiveRole,
    Relationship,
    Resource,
    ViewerContext,
    authorize,
    build_viewer_context,
    project,
)
from app.core.authz import field_registry as fr

OWNER = "athlete-1"

PROFILE = {
    "sportsz_id": "SZ-AAA1",
    "user_id": OWNER,
    "full_name": "Asha Rao",
    "photo_url": "http://x/p.jpg",
    "sports": [{"sport_name": "Cricket"}],
    "bio": "bio",
    "city": "Pune",
    "region": "MH",
    "experience": [],
    "sport_profiles": {},
    "physical": {"height_cm": 170},
    "date_of_birth": "2005-01-01",
    "gender": "F",
    "privacy": {"discoverable": True, "field_overrides": {}},
    "internal_secret_flag": True,  # not in registry -> must never leak
}


def viewer(uid, role, **kw):
    return ViewerContext(
        user_id=uid, roles=frozenset({role}), active_role=role, **kw
    )


def res(rel=None, discoverable=True):
    return Resource(
        type="athlete_profile",
        owner_id=OWNER,
        discoverable=discoverable,
        relationship=rel or Relationship(),
    )


# ---------------- viewer_context ----------------

def test_single_string_role_from_m1():
    v = build_viewer_context({"user_id": "u", "role": "athlete"})
    assert v.active_role == "athlete" and v.roles == {"athlete"}


def test_roles_list_supported():
    v = build_viewer_context({"user_id": "u", "roles": ["athlete", "coach"]}, "coach")
    assert v.active_role == "coach"


def test_multi_role_without_header_has_no_active_role():
    v = build_viewer_context({"user_id": "u", "roles": ["athlete", "coach"]})
    assert v.active_role is None


def test_header_for_role_not_held_is_rejected():
    with pytest.raises(InvalidActiveRole):
        build_viewer_context({"user_id": "u", "role": "athlete"}, "admin")


def test_unassigned_user_has_no_roles():
    v = build_viewer_context({"user_id": "u", "role": None})
    assert v.roles == frozenset() and v.active_role is None


# ---------------- authorize: role x relationship x privacy matrix ----------------

ATH = viewer("athlete-2", "athlete")
COACH_V = viewer("coach-v", "coach", coach_verified=True)
COACH_U = viewer("coach-u", "coach", coach_verified=False)
RECR_V = viewer("recr-v", "recruiter", recruiter_verified=True)
RECR_U = viewer("recr-u", "recruiter", recruiter_verified=False)
ADMIN = viewer("admin", "admin")
SELF = viewer(OWNER, "athlete")

LINKED = Relationship(active_coach_link=True)
CONNECTED = Relationship(connection_accepted=True)
BLOCKED = Relationship(blocked=True)
NONE = Relationship()

# (viewer, relationship, discoverable, action, expected_status)
MATRIX = [
    # self always allowed, even if blocked flag or not discoverable
    (SELF, NONE, True, "read", 200),
    (SELF, BLOCKED, False, "read", 200),
    (SELF, NONE, True, "write", 200),
    # other athlete
    (ATH, NONE, True, "read", 200),
    (ATH, NONE, False, "read", 404),
    (ATH, CONNECTED, False, "read", 200),
    (ATH, BLOCKED, True, "read", 404),
    (ATH, NONE, True, "write", 403),
    (ATH, NONE, True, "delete", 403),
    # verified coach
    (COACH_V, NONE, True, "read", 200),
    (COACH_V, NONE, False, "read", 404),
    (COACH_V, LINKED, False, "read", 200),
    (COACH_V, LINKED, True, "write", 403),
    (COACH_V, BLOCKED, True, "read", 404),
    (COACH_V, Relationship(blocked=True, active_coach_link=True), True, "read", 404),
    # unverified coach behaves like an ordinary user
    (COACH_U, NONE, True, "read", 200),
    (COACH_U, NONE, False, "read", 404),
    (COACH_U, BLOCKED, True, "read", 404),
    # recruiter
    (RECR_V, NONE, True, "read", 200),
    (RECR_V, NONE, False, "read", 404),
    (RECR_V, CONNECTED, False, "read", 200),
    (RECR_V, BLOCKED, True, "read", 404),
    (RECR_V, NONE, True, "write", 403),
    (RECR_U, NONE, True, "read", 200),
    (RECR_U, BLOCKED, True, "read", 404),
    # admin
    (ADMIN, NONE, True, "read", 200),
    (ADMIN, NONE, False, "read", 200),
    (ADMIN, BLOCKED, True, "read", 404),
    (ADMIN, NONE, True, "write", 403),
    # platform-blocked user
    (viewer("bad", "athlete", is_blocked_user=True), NONE, True, "read", 404),
    (viewer("bad", "coach", is_blocked_user=True, coach_verified=True), LINKED, True, "read", 404),
    # no active role
    (ViewerContext("u", frozenset({"athlete", "coach"}), None), NONE, True, "read", 404),
]


@pytest.mark.parametrize("v,rel,disc,action,status", MATRIX)
def test_authorize_matrix(v, rel, disc, action, status):
    d = authorize(v, res(rel, disc), action)
    assert d.status == status
    assert d.allowed == (status == 200)


def test_hidden_is_identical_to_missing_response():
    """Enumeration: a hidden profile and a non-existent id must look the same."""
    hidden = authorize(ATH, res(BLOCKED), "read")
    assert (hidden.status, hidden.code) == (404, "NOT_FOUND")


# ---------------- authorize: IDOR on participant-only resources ----------------

@pytest.mark.parametrize("rtype", ["conversation", "message", "connection", "coach_link", "access_grant"])
def test_idor_non_participant_gets_404(rtype):
    r = Resource(type=rtype, participant_ids=frozenset({"a", "b"}))
    assert authorize(viewer("c", "athlete"), r).status == 404
    assert authorize(viewer("a", "athlete"), r).allowed
    assert authorize(viewer("b", "athlete"), r).allowed


def test_admin_can_read_but_not_write_participant_resource():
    r = Resource(type="conversation", participant_ids=frozenset({"a", "b"}))
    assert authorize(ADMIN, r, "read").allowed
    assert authorize(ADMIN, r, "write").status == 404


# ---------------- project: field registry ----------------

def keys(v, rel=NONE, doc=PROFILE, **kw):
    return set(project(v, doc, res(rel, **kw)))


def test_default_deny_unknown_field_never_leaks():
    for v in (SELF, ADMIN, ATH, COACH_V, RECR_V):
        assert "internal_secret_flag" not in keys(v)


def test_unknown_resource_type_returns_nothing():
    assert project(SELF, PROFILE, Resource(type="nope", owner_id=OWNER)) == {}


def test_self_sees_everything_registered():
    assert keys(SELF) == set(fr.FIELD_REGISTRY["athlete_profile"]) & set(PROFILE)


def test_other_athlete_view():
    k = keys(ATH)
    assert {"full_name", "sports", "bio", "city"} <= k
    assert not ({"date_of_birth", "gender", "privacy", "user_id", "physical"} & k)


def test_linked_coach_sees_physical_but_unlinked_coach_does_not():
    assert "physical" in keys(COACH_V, LINKED)
    assert "physical" not in keys(COACH_V, NONE)


def test_recruiter_sees_physical_not_dob():
    k = keys(RECR_V)
    assert "physical" in k and "date_of_birth" not in k


def test_unverified_coach_gets_athlete_view():
    assert keys(COACH_U) == keys(ATH)


def test_admin_sees_sensitive_fields():
    assert {"date_of_birth", "gender", "privacy"} <= keys(ADMIN)


def test_public_whitelist_only():
    out = project(None, PROFILE, res(), public=True)
    assert set(out) == {"sportsz_id", "full_name", "photo_url", "sports"}


def test_owner_override_hides_field_from_others_not_from_self_or_admin():
    doc = {**PROFILE, "privacy": {"field_overrides": {"bio": "hidden", "city": "hidden"}}}
    assert not ({"bio", "city"} & keys(ATH, doc=doc))
    assert not ({"bio", "city"} & keys(COACH_V, LINKED, doc=doc))
    assert {"bio", "city"} <= keys(SELF, doc=doc)
    assert {"bio", "city"} <= keys(ADMIN, doc=doc)


def test_override_cannot_widen_or_hide_unhideable_field():
    doc = {**PROFILE, "privacy": {"field_overrides": {"date_of_birth": "public", "full_name": "hidden"}}}
    assert "date_of_birth" not in keys(ATH, doc=doc)
    assert "full_name" in keys(ATH, doc=doc)  # identity field is not hideable


def test_project_does_not_mutate_input():
    snapshot = dict(PROFILE)
    project(ATH, PROFILE, res())
    assert PROFILE == snapshot


def test_view_as_equals_real_projection():
    """PR08 'View as coach' must be the SAME function the real coach path uses."""
    real = project(COACH_V, PROFILE, res(LINKED))
    preview = project(
        ViewerContext("preview", frozenset({"coach"}), "coach", coach_verified=True),
        PROFILE,
        res(LINKED),
    )
    assert real == preview
