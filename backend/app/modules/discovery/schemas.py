from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict


SavedType = Literal["opportunity", "event"]


class _Base(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SavedCreateRequest(_Base):
    type: SavedType
    target_id: str


class SavedOpportunitySummary(_Base):
    title: str
    type: str
    sport_id: str
    organization_name: str
    location: str
    deadline: Optional[datetime] = None
    status: str


class SavedEventSummary(_Base):
    title: str
    sport_id: str
    location: str
    starts_at: datetime
    status: str


class SavedItem(_Base):
    type: SavedType
    target_id: str
    saved_at: datetime
    available: bool
    summary: Optional[SavedOpportunitySummary | SavedEventSummary] = None


class SavedMeta(_Base):
    next_cursor: Optional[str] = None
    request_id: str


class SavedItemResponse(_Base):
    data: SavedItem
    meta: SavedMeta


class SavedListResponse(_Base):
    data: list[SavedItem]
    meta: SavedMeta
