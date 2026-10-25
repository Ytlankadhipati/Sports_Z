from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class ConnectionCreate(_In):
    target_user_id: str = Field(min_length=1, max_length=64)
    note: str | None = Field(default=None, max_length=500)  # real limit (140) from platform_config in service


class ConnectionRespond(_In):
    decision: Literal["accept", "decline"]


class BlockCreate(_In):
    target_user_id: str = Field(min_length=1, max_length=64)


class CoachLinkCreate(_In):
    counterpart_user_id: str = Field(min_length=1, max_length=64)
    sport_id: str = Field(min_length=1, max_length=80)


class GrantRequestCreate(_In):
    owner_user_id: str = Field(min_length=1, max_length=64)
    scopes: list[str] = Field(min_length=1, max_length=10)


class GrantCreate(_In):
    grantee_user_id: str = Field(min_length=1, max_length=64)
    scopes: list[str] = Field(min_length=1, max_length=10)
    expires_at: datetime | None = None


class GrantApprove(_In):
    expires_at: datetime | None = None
