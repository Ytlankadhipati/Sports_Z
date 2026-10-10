from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict


class _Base(BaseModel):
    model_config = ConfigDict(extra="forbid")


RegistrationState = Literal["not_registered", "registered", "waitlisted"]
RegistrationStatus = Literal["registered", "waitlisted"]


class EventSummary(_Base):
    public_id: str
    title: str
    sport_id: str
    location: str
    starts_at: datetime
    registration_deadline: Optional[datetime] = None
    seats_left: int
    status: str
    registration_state: RegistrationState


class EventDetail(EventSummary):
    description: str
    capacity: int
    is_saved: bool


class EventRegistrationResult(_Base):
    event_public_id: str
    status: RegistrationStatus
    created_at: datetime


class MyEventRegistration(_Base):
    event_public_id: str
    title: str
    starts_at: datetime
    location: str
    registration_status: RegistrationStatus
    created_at: datetime


class CancellationResult(_Base):
    cancelled: bool


class Meta(_Base):
    next_cursor: Optional[str] = None
    request_id: str


class EventListResponse(_Base):
    data: List[EventSummary]
    meta: Meta


class EventDetailResponse(_Base):
    data: EventDetail
    meta: Meta


class EventRegistrationResponse(_Base):
    data: EventRegistrationResult
    meta: Meta


class CancellationResponse(_Base):
    data: CancellationResult
    meta: Meta


class MyEventRegistrationsResponse(_Base):
    data: List[MyEventRegistration]
    meta: Meta
