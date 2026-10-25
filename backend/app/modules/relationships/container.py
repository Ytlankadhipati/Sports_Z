"""Wires repositories and services for M4. One place, built lazily from M1's db."""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Callable

from app.core.platform_config import PlatformConfigService
from app.core.ratelimit import RateLimiter
from app.modules.messaging.repository import ConversationRepository, MessageRepository
from app.modules.messaging.service import MessagingService, no_applications
from app.modules.relationships.repository import (
    AccessGrantRepository,
    CoachLinkRepository,
    ConnectionRepository,
    MongoUserDirectory,
)
from app.modules.relationships.service import (
    AccessGrantService,
    CoachLinkService,
    ConnectionService,
    RelationshipResolver,
)


@dataclass
class M4Container:
    config: PlatformConfigService
    limiter: RateLimiter
    directory: Any
    resolver: RelationshipResolver
    connections: ConnectionService
    links: CoachLinkService
    grants: AccessGrantService
    messaging: MessagingService
    load_profile: Callable[[str], dict[str, Any] | None]
    repos: list[Any]

    def ensure_indexes(self) -> None:
        for r in self.repos:
            r.ensure_indexes()


def build_container(db, users, profiles, *, load_profile=None, has_application=no_applications,
                    sportsz_ids=None) -> M4Container:
    config = PlatformConfigService(db["platform_config"])
    limiter = RateLimiter()
    directory = MongoUserDirectory(users, profiles)
    conn_repo = ConnectionRepository(db["connections"])
    link_repo = CoachLinkRepository(db["coach_athlete_links"])
    grant_repo = AccessGrantRepository(db["access_grants"])
    conv_repo = ConversationRepository(db["conversations"])
    msg_repo = MessageRepository(db["messages"])
    resolver = RelationshipResolver(conn_repo, link_repo, grant_repo)
    grants = AccessGrantService(grant_repo, directory, config, resolver.is_blocked)
    if load_profile is None:
        def load_profile(user_id: str):
            p = profiles.find_one({"user_id": user_id}, {"_id": 0})
            if p is None:
                return None
            if sportsz_ids is not None:
                s = sportsz_ids.find_one({"user_id": user_id}) or {}
                p["sportsz_id"] = s.get("sportsz_id")
            return p
    return M4Container(
        config=config, limiter=limiter, directory=directory, resolver=resolver,
        connections=ConnectionService(conn_repo, directory, config, limiter),
        links=CoachLinkService(link_repo, directory, grants, resolver.is_blocked),
        grants=grants,
        messaging=MessagingService(conv_repo, msg_repo, directory, resolver, config, limiter, has_application),
        load_profile=load_profile,
        repos=[conn_repo, link_repo, grant_repo, conv_repo, msg_repo],
    )


@lru_cache(maxsize=1)
def get_container() -> M4Container:
    from app.core.database import db, sports_ids_collection, athlete_profiles_collection, users_collection
    return build_container(db, users_collection, athlete_profiles_collection, sportsz_ids=sports_ids_collection)


def ensure_indexes() -> None:
    get_container().ensure_indexes()
