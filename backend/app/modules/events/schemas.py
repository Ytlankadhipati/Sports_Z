from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class _Base(BaseModel):
    model_config = ConfigDict(extra="forbid")


class EventSummary(_Base):
    public_id: str
    title: str
    sport_id: str
    location: str
    starts_at: datetime
    registration_deadline: Optional[datetime] = None
    seats_left: int
    status: str


class EventDetail(EventSummary):
    description: str
    capacity: int


class Meta(_Base):
    next_cursor: Optional[str] = None
    request_id: str


class EventListResponse(_Base):
    data: List[EventSummary]
    meta: Meta


class EventDetailResponse(_Base):
    data: EventDetail
    meta: Meta