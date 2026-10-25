"""M4 service tests on mongomock (no Firebase, no real Mongo)."""

import pytest

mongomock = pytest.importorskip("mongomock")

from datetime import timedelta  # noqa: E402

from app.core.platform_config import PlatformConfigService  # noqa: E402
from app.core.ratelimit import RateLimiter, RateLimitExceeded  # noqa: E402
from app.devtools.fixtures import reset_fixture_data, seed_fixtures  # noqa: E402
from app.devtools.router import ActRequest, _viewer, perform  # noqa: E402
from app.modules.messaging.rules import Facts, Party, can_send_message, can_start_conversation  # noqa: E402
from app.modules.relationships import privacy  # noqa: E402
from app.modules.relationships.container import build_container  # noqa: E402
from app.modules.relationships.errors import (  # noqa: E402
    ConflictError, ForbiddenError, NotFoundError, RateLimited, ValidationFailed,
)
from app.modules.relationships.repository import utcnow  # noqa: E402


@pytest.fixture()
def env():
    db = mongomock.MongoClient()["t"]
    users, profiles = db["users"], db["athlete_profiles"]
    applications = set()
    c = build_container(db, users, profiles, has_application=lambda a, r: (a, r) in applications)
    c.ensure_indexes()
    ids = seed_fixtures(users, profiles)

    class E:
        pass

    e = E()
    e.db, e.users, e.c, e.ids, e.applications = db, users, c, ids, applications
    e.v = lambda name: _viewer(c, users, name)
    return e


# ---------------- platform_config / rate limit ----------------
def test_platform_config_defaults_and_override():
    db = mongomock.MongoClient()["t"]
    cfg = PlatformConfigService(db["platform_config"], ttl_seconds=0)
    assert cfg.get_int("limits.message_max_chars", 0) == 1000
    db["platform_config"].insert_one({"_id": "limits", "values": {"message_max_chars": 50}})
    assert cfg.get_int("limits.message_max_chars", 0) == 50


def test_rate_limiter_blocks_after_limit_and_recovers():
    t = [0.0]
    rl = RateLimiter(clock=lambda: t[0])
    for _ in range(3):
        rl.check("k", 3, 60)
    with pytest.raises(RateLimitExceeded):
        rl.check("k", 3, 60)
    t[0] = 61
    rl.check("k", 3, 60)


# ---------------- messaging rules (ADR-001): every pair ----------------
ATH = Party("a", "athlete")
COACH_V, COACH_U = Party("c", "coach", True), Party("c", "coach", False)
RECR_V, RECR_U = Party("r", "recruiter", True), Party("r", "recruiter", False)

CASES = [  # (starter, other, facts, expected_ok, basis)
    (ATH, COACH_V, Facts(connection_accepted=True), True, "connection"),
    (ATH, COACH_V, Facts(active_coach_link=True), True, "link"),
    (COACH_V, ATH, Facts(active_coach_link=True), True, "link"),
    (ATH, COACH_V, Facts(), False, None),                                   # no basis
    (ATH, COACH_V, Facts(connection_accepted=True, blocked=True), False, None),
    (ATH, COACH_V, Facts(active_coach_link=True, blocked=True), False, None),
    (ATH, COACH_U, Facts(connection_accepted=True), False, None),           # unverified
    (COACH_U, ATH, Facts(active_coach_link=True), False, None),             # unverified starter
    (ATH, COACH_V, Facts(has_application=True), False, None),               # application is recruiter-only
    (ATH, RECR_V, Facts(connection_accepted=True), True, "connection"),
    (ATH, RECR_V, Facts(has_application=True), True, "application"),
    (RECR_V, ATH, Facts(has_application=True), True, "application"),
    (ATH, RECR_V, Facts(active_coach_link=True), False, None),              # link is coach-only
    (ATH, RECR_V, Facts(), False, None),
    (ATH, RECR_V, Facts(has_application=True, blocked=True), False, None),
    (ATH, RECR_U, Facts(has_application=True), False, None),
    (RECR_U, ATH, Facts(connection_accepted=True), False, None),
    (ATH, Party("a2", "athlete"), Facts(connection_accepted=True), False, None),   # athlete<->athlete: Phase 2
    (COACH_V, RECR_V, Facts(connection_accepted=True), False, None),
    (ATH, Party("o", "org", True), Facts(connection_accepted=True), False, None),
    (ATH, Party("a", "athlete"), Facts(), False, None),                     # self
]


@pytest.mark.parametrize("starter,other,facts,ok,basis", CASES)
def test_can_start_conversation(starter, other, facts, ok, basis):
    v = can_start_conversation(starter, other, facts)
    assert v.ok == ok and v.basis == basis


def test_unverified_pro_may_reply_but_not_when_blocked_or_basis_gone():
    assert can_send_message(COACH_U, ATH, Facts(connection_accepted=True)).ok
    assert not can_send_message(COACH_U, ATH, Facts(connection_accepted=True, blocked=True)).ok
    assert not can_send_message(COACH_U, ATH, Facts()).ok


# ---------------- connections ----------------
def test_connection_flow_and_note_limit(env):
    a1, a2 = env.v("ATHLETE_1"), env.v("RECR_V")
    with pytest.raises(ValidationFailed):
        env.c.connections.request(a1, env.ids["RECR_V"], "x" * 141)
    conn = env.c.connections.request(a1, env.ids["RECR_V"], "x" * 140)
    assert conn["status"] == "requested" and conn["direction"] == "outgoing"
    with pytest.raises(ConflictError):
        env.c.connections.request(a1, env.ids["RECR_V"], None)
    with pytest.raises(ForbiddenError):  # requester cannot accept their own request
        env.c.connections.respond(a1, conn["id"], "accept")
    assert env.c.connections.respond(a2, conn["id"], "accept")["status"] == "accepted"
    with pytest.raises(ConflictError):
        env.c.connections.respond(a2, conn["id"], "decline")


def test_cannot_connect_to_self_or_unknown(env):
    with pytest.raises(ValidationFailed):
        env.c.connections.request(env.v("ATHLETE_1"), env.ids["ATHLETE_1"], None)
    with pytest.raises(NotFoundError):
        env.c.connections.request(env.v("ATHLETE_1"), "64b000000000000000000000", None)


def test_decline_then_new_request_allowed(env):
    a, r = env.v("ATHLETE_1"), env.v("RECR_V")
    conn = env.c.connections.request(a, env.ids["RECR_V"], None)
    env.c.connections.respond(r, conn["id"], "decline")
    assert env.c.connections.request(a, env.ids["RECR_V"], None)["status"] == "requested"


def test_block_hides_everything_both_ways_and_unblock_restores(env):
    a, r = env.v("ATHLETE_1"), env.v("RECR_V")
    blocked = env.c.connections.block(a, env.ids["RECR_V"])
    assert blocked["status"] == "blocked" and blocked["blocked_by_me"]
    # blocked side cannot request, and gets the SAME 404 as an unknown user
    with pytest.raises(NotFoundError):
        env.c.connections.request(r, env.ids["ATHLETE_1"], None)
    # blocked side does not see the block in their list
    items, _ = env.c.connections.list(r, None, 20, None)
    assert items == []
    rel = env.c.resolver.relationship(r, env.ids["ATHLETE_1"])
    assert rel.blocked
    env.c.connections.unblock(a, blocked["id"])
    assert not env.c.resolver.relationship(r, env.ids["ATHLETE_1"]).blocked


def test_only_blocker_can_unblock(env):
    a, r = env.v("ATHLETE_1"), env.v("RECR_V")
    blocked = env.c.connections.block(a, env.ids["RECR_V"])
    with pytest.raises(NotFoundError):
        env.c.connections.unblock(r, blocked["id"])


def test_idor_connection_other_user(env):
    conn = env.c.connections.request(env.v("ATHLETE_1"), env.ids["RECR_V"], None)
    stranger = env.v("ATHLETE_2")
    for fn in (lambda: env.c.connections.respond(stranger, conn["id"], "accept"),
               lambda: env.c.connections.block_by_connection(stranger, conn["id"]),
               lambda: env.c.connections.unblock(stranger, conn["id"])):
        with pytest.raises(NotFoundError):
            fn()
    with pytest.raises(NotFoundError):
        env.c.connections.respond(stranger, "not-an-object-id", "accept")


def test_platform_blocked_user_cannot_use_relationships(env):
    with pytest.raises(ForbiddenError):
        env.c.connections.request(env.v("USER_BLOCKED"), env.ids["RECR_V"], None)


def test_org_and_admin_roles_cannot_connect(env):
    for name in ("ORG_V", "ADMIN"):
        with pytest.raises(ForbiddenError):
            env.c.connections.request(env.v(name), env.ids["ATHLETE_1"], None)


# ---------------- coach links ----------------
def test_link_lifecycle_and_unique_open_link(env):
    coach, ath = env.v("COACH_V"), env.v("ATHLETE_1")
    link = env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")
    assert link["status"] == "requested" and link["initiated_by_me"]
    with pytest.raises(ConflictError):
        env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")
    with pytest.raises(ConflictError):     # athlete-initiated duplicate too
        env.c.links.request(ath, env.ids["COACH_V"], "cricket")
    assert env.c.links.request(coach, env.ids["ATHLETE_1"], "football")["status"] == "requested"  # other sport ok
    with pytest.raises(ForbiddenError):    # initiator cannot approve own request
        env.c.links.approve(coach, link["id"])
    assert env.c.links.approve(ath, link["id"])["status"] == "active"
    with pytest.raises(ConflictError):
        env.c.links.approve(ath, link["id"])


def test_decline_frees_the_slot(env):
    coach, ath = env.v("COACH_V"), env.v("ATHLETE_1")
    link = env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")
    env.c.links.decline(ath, link["id"])
    assert env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")["status"] == "requested"


def test_unverified_coach_cannot_link_either_direction(env):
    with pytest.raises(ForbiddenError):
        env.c.links.request(env.v("COACH_U"), env.ids["ATHLETE_1"], "cricket")
    with pytest.raises(ForbiddenError):
        env.c.links.request(env.v("ATHLETE_1"), env.ids["COACH_U"], "cricket")


def test_link_only_between_athlete_and_coach(env):
    with pytest.raises(ForbiddenError):
        env.c.links.request(env.v("RECR_V"), env.ids["ATHLETE_1"], "cricket")
    with pytest.raises(ForbiddenError):
        env.c.links.request(env.v("ATHLETE_1"), env.ids["ATHLETE_2"], "cricket")


def test_ending_link_revokes_linked_access_immediately(env):
    coach, ath = env.v("COACH_V"), env.v("ATHLETE_1")
    link = env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")
    env.c.links.approve(ath, link["id"])
    env.c.grants.issue(env.ids["ATHLETE_1"], env.ids["COACH_V"], ["physical"], source="link", source_ref=link["id"])
    assert env.c.resolver.relationship(coach, env.ids["ATHLETE_1"]).active_coach_link
    assert "physical" in env.c.resolver.relationship(coach, env.ids["ATHLETE_1"]).grant_scopes
    env.c.links.end(ath, link["id"])
    rel = env.c.resolver.relationship(coach, env.ids["ATHLETE_1"])
    assert not rel.active_coach_link and not rel.grant_scopes


def test_ended_link_cannot_be_ended_again_and_idor(env):
    coach, ath = env.v("COACH_V"), env.v("ATHLETE_1")
    link = env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")
    with pytest.raises(NotFoundError):
        env.c.links.end(env.v("ATHLETE_2"), link["id"])
    env.c.links.end(coach, link["id"])     # requester cancels
    with pytest.raises(ConflictError):
        env.c.links.end(coach, link["id"])


def test_blocked_pair_cannot_link(env):
    env.c.connections.block(env.v("ATHLETE_1"), env.ids["COACH_V"])
    with pytest.raises(NotFoundError):
        env.c.links.request(env.v("COACH_V"), env.ids["ATHLETE_1"], "cricket")


# ---------------- access grants ----------------
def test_grant_request_approve_revoke_and_expiry(env):
    coach, ath = env.v("COACH_V"), env.v("ATHLETE_1")
    req = env.c.grants.request_access(coach, env.ids["ATHLETE_1"], ["physical", "certificates"])
    assert req["status"] == "requested"
    with pytest.raises(ForbiddenError):
        env.c.grants.grant(coach, req["id"])     # grantee cannot self-approve
    with pytest.raises(NotFoundError):
        env.c.grants.grant(env.v("ATHLETE_2"), req["id"])  # IDOR
    g = env.c.grants.grant(ath, req["id"], utcnow() + timedelta(days=1))
    assert g["status"] == "active"
    assert env.c.resolver.grant_scopes(env.ids["ATHLETE_1"], env.ids["COACH_V"]) == {"physical", "certificates"}
    env.c.grants.revoke(ath, req["id"])
    assert env.c.resolver.grant_scopes(env.ids["ATHLETE_1"], env.ids["COACH_V"]) == frozenset()


def test_expired_grant_gives_no_access(env):
    clock = [utcnow()]
    env.c.resolver._now = lambda: clock[0]
    env.c.grants.issue(env.ids["ATHLETE_1"], env.ids["RECR_V"], ["contact"], utcnow() + timedelta(hours=1),
                       source="application", source_ref="app-1")
    assert env.c.resolver.grant_scopes(env.ids["ATHLETE_1"], env.ids["RECR_V"]) == {"contact"}
    clock[0] += timedelta(hours=2)
    assert env.c.resolver.grant_scopes(env.ids["ATHLETE_1"], env.ids["RECR_V"]) == frozenset()


def test_grant_validation(env):
    ath = env.v("ATHLETE_1")
    with pytest.raises(ValidationFailed):
        env.c.grants.create_direct(ath, env.ids["COACH_V"], ["not_a_scope"])
    with pytest.raises(ValidationFailed):
        env.c.grants.create_direct(ath, env.ids["COACH_V"], [])
    with pytest.raises(ValidationFailed):
        env.c.grants.create_direct(ath, env.ids["COACH_V"], ["physical"], utcnow() - timedelta(days=1))
    assert env.c.grants.create_direct(ath, env.ids["COACH_V"], ["physical"])["expires_at"]  # default expiry set


def test_blocked_cannot_request_grant(env):
    env.c.connections.block(env.v("ATHLETE_1"), env.ids["RECR_V"])
    with pytest.raises(NotFoundError):
        env.c.grants.request_access(env.v("RECR_V"), env.ids["ATHLETE_1"], ["contact"])


def test_grant_list_idor(env):
    env.c.grants.create_direct(env.v("ATHLETE_1"), env.ids["COACH_V"], ["physical"])
    mine, _ = env.c.grants.list(env.v("ATHLETE_1"), None, None, 20, None)
    other, _ = env.c.grants.list(env.v("ATHLETE_2"), None, None, 20, None)
    assert len(mine) == 1 and other == []


# ---------------- messaging service ----------------
def connect(env, a, b):
    conn = env.c.connections.request(env.v(a), env.ids[b], None)
    env.c.connections.respond(env.v(b), conn["id"], "accept")
    return conn


def test_start_send_list_and_read_only_after_block(env):
    connect(env, "ATHLETE_1", "COACH_V")
    ath, coach = env.v("ATHLETE_1"), env.v("COACH_V")
    started = env.c.messaging.start(ath, env.ids["COACH_V"], "hello coach")
    cid = started["conversation_id"]
    env.c.messaging.send(coach, cid, "hi!")
    data, _ = env.c.messaging.list_messages(ath, cid, 30, None)
    assert [m["text"] for m in data["messages"]] == ["hi!", "hello coach"] and not data["conversation"]["read_only"]
    env.c.connections.block(ath, env.ids["COACH_V"])
    with pytest.raises(NotFoundError):
        env.c.messaging.send(coach, cid, "still there?")      # blocked side: looks missing
    with pytest.raises(NotFoundError):
        env.c.messaging.send(ath, cid, "x")                   # blocker cannot write either
    data, _ = env.c.messaging.list_messages(ath, cid, 30, None)
    assert data["conversation"]["read_only"] and len(data["messages"]) == 2   # history still readable


def test_cannot_start_without_basis_or_with_unverified(env):
    with pytest.raises(ForbiddenError):
        env.c.messaging.start(env.v("ATHLETE_1"), env.ids["COACH_V"], "hi")
    connect(env, "ATHLETE_1", "COACH_U")
    with pytest.raises(ForbiddenError):
        env.c.messaging.start(env.v("ATHLETE_1"), env.ids["COACH_U"], "hi")
    with pytest.raises(NotFoundError):    # athlete <-> athlete not allowed in Phase 1
        env.c.messaging.start(env.v("ATHLETE_1"), env.ids["ATHLETE_2"], "hi")


def test_recruiter_application_basis_via_m3_lookup(env):
    with pytest.raises(ForbiddenError):
        env.c.messaging.start(env.v("RECR_V"), env.ids["ATHLETE_1"], "hi")
    env.applications.add((env.ids["ATHLETE_1"], env.ids["RECR_V"]))
    assert env.c.messaging.start(env.v("RECR_V"), env.ids["ATHLETE_1"], "hi")["conversation_id"]


def test_ending_link_makes_conversation_read_only_unless_connected(env):
    coach, ath = env.v("COACH_V"), env.v("ATHLETE_1")
    link = env.c.links.request(coach, env.ids["ATHLETE_1"], "cricket")
    env.c.links.approve(ath, link["id"])
    cid = env.c.messaging.start(coach, env.ids["ATHLETE_1"], "welcome")["conversation_id"]
    env.c.links.end(ath, link["id"])
    with pytest.raises(ForbiddenError):
        env.c.messaging.send(ath, cid, "bye")
    data, _ = env.c.messaging.list_messages(ath, cid, 30, None)
    assert data["conversation"]["read_only"] and data["conversation"]["read_only_reason"] == "basis_ended"


def test_message_length_from_platform_config_and_empty(env):
    connect(env, "ATHLETE_1", "COACH_V")
    ath = env.v("ATHLETE_1")
    with pytest.raises(ValidationFailed):
        env.c.messaging.start(ath, env.ids["COACH_V"], "x" * 1001)
    with pytest.raises(ValidationFailed):
        env.c.messaging.start(ath, env.ids["COACH_V"], "   ")
    env.db["platform_config"].insert_one({"_id": "limits", "values": {"message_max_chars": 5}})
    env.c.config.clear_cache()
    with pytest.raises(ValidationFailed):
        env.c.messaging.start(ath, env.ids["COACH_V"], "123456")


def test_message_rate_limit(env):
    connect(env, "ATHLETE_1", "COACH_V")
    ath = env.v("ATHLETE_1")
    cid = env.c.messaging.start(ath, env.ids["COACH_V"], "m0")["conversation_id"]
    with pytest.raises(RateLimited):
        for i in range(1, 30):
            env.c.messaging.send(ath, cid, f"m{i}")


def test_conversation_idor(env):
    connect(env, "ATHLETE_1", "COACH_V")
    cid = env.c.messaging.start(env.v("ATHLETE_1"), env.ids["COACH_V"], "private")["conversation_id"]
    stranger = env.v("ATHLETE_2")
    for fn in (lambda: env.c.messaging.list_messages(stranger, cid, 30, None),
               lambda: env.c.messaging.send(stranger, cid, "hi"),
               lambda: env.c.messaging.mark_read(stranger, cid),
               lambda: env.c.messaging.set_mute(stranger, cid, True),
               lambda: env.c.messaging.delete_for_me(stranger, cid)):
        with pytest.raises(NotFoundError):
            fn()
    items, _ = env.c.messaging.list_conversations(stranger, 20, None)
    assert items == []


def test_mute_read_delete_are_per_user(env):
    connect(env, "ATHLETE_1", "COACH_V")
    ath, coach = env.v("ATHLETE_1"), env.v("COACH_V")
    cid = env.c.messaging.start(ath, env.ids["COACH_V"], "hello")["conversation_id"]
    assert env.c.messaging.list_conversations(coach, 20, None)[0][0]["unread_count"] == 1
    env.c.messaging.mark_read(coach, cid)
    assert env.c.messaging.list_conversations(coach, 20, None)[0][0]["unread_count"] == 0
    assert env.c.messaging.set_mute(coach, cid, True)["muted"]
    assert not env.c.messaging.list_conversations(ath, 20, None)[0][0]["muted"]
    env.c.messaging.delete_for_me(ath, cid)
    assert env.c.messaging.list_conversations(ath, 20, None)[0] == []
    assert len(env.c.messaging.list_conversations(coach, 20, None)[0]) == 1
    env.c.messaging.send(coach, cid, "you there?")      # new message re-opens it
    assert len(env.c.messaging.list_conversations(ath, 20, None)[0]) == 1


def test_search_filters_conversations(env):
    connect(env, "ATHLETE_1", "COACH_V")
    env.c.messaging.start(env.v("ATHLETE_1"), env.ids["COACH_V"], "about trials")
    assert len(env.c.messaging.list_conversations(env.v("ATHLETE_1"), 20, None, "trials")[0]) == 1
    assert env.c.messaging.list_conversations(env.v("ATHLETE_1"), 20, None, "zzz")[0] == []


# ---------------- privacy ----------------
PROFILE = {"sportsz_id": "SZ-1", "full_name": "A", "photo_url": "p", "sports": [], "bio": "b",
           "physical": {"h": 1}, "date_of_birth": "2005-01-01", "privacy": {"field_overrides": {"bio": "hidden"}}}


def test_preview_equals_real_projection():
    from app.core.authz import Relationship, Resource, ViewerContext, project
    real = project(ViewerContext("c", frozenset({"coach"}), "coach", coach_verified=True), PROFILE,
                   Resource("athlete_profile", "o", relationship=Relationship(active_coach_link=True)))
    assert privacy.preview_profile(PROFILE, "o", "linked_coach") == real
    assert "physical" in real and "date_of_birth" not in real and "bio" not in real


def test_preview_public_is_whitelist_and_bad_audience_rejected():
    assert set(privacy.preview_profile(PROFILE, "o", "public")) == {"sportsz_id", "full_name", "photo_url", "sports"}
    with pytest.raises(ValidationFailed):
        privacy.preview_profile(PROFILE, "o", "admin")


def test_privacy_schema_lists_hideable_fields():
    s = privacy.privacy_schema()
    assert {f["field"] for f in s["fields"]} >= {"bio", "city", "physical"}
    assert "contact_policy" in s and "public" in s["preview_audiences"]


# ---------------- devtools ----------------
def test_seed_is_idempotent_and_reset_only_touches_fixtures(env):
    again = seed_fixtures(env.users, env.db["athlete_profiles"])
    assert again == env.ids and env.users.count_documents({"is_fixture": True}) == 9
    real = env.users.insert_one({"firebase_uid": "real", "role": "athlete"}).inserted_id
    env.c.connections.request(env.v("COACH_V"), env.ids["ATHLETE_1"], None)
    env.db["connections"].insert_one({"pair_key": "x|y", "participants": [str(real), "someone"], "status": "requested"})
    counts = reset_fixture_data(env.db, env.ids)
    assert counts["connections"] == 1 and env.db["connections"].count_documents({}) == 1


def test_console_acts_through_real_services_and_rules(env):
    out = perform(env.c, env.users, ActRequest(fixture="COACH_V", action="link_request",
                                               target_user_id=env.ids["ATHLETE_1"], sport_id="cricket"))
    assert out["status"] == "requested"
    with pytest.raises(ForbiddenError):    # console cannot bypass verification rule
        perform(env.c, env.users, ActRequest(fixture="COACH_U", action="link_request",
                                             target_user_id=env.ids["ATHLETE_1"], sport_id="cricket"))
    with pytest.raises(ValidationFailed):
        perform(env.c, env.users, ActRequest(fixture="NOPE", action="connect", target_user_id="x"))
