from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class _Base(BaseModel):
    model_config = ConfigDict(extra="forbid")


class OpportunitySummary(_Base):
    public_id: str
    title: str
    type: str
    sport_id: str
    organization_name: str
    location: str
    deadline: Optional[datetime] = None
    status: str


class OpportunityDetail(OpportunitySummary):
    description: str
    eligibility_summary: str
    is_saved: bool


class Meta(_Base):
    next_cursor: Optional[str] = None
    request_id: str


class OpportunityListResponse(_Base):
    data: List[OpportunitySummary]
    meta: Meta


class OpportunityDetailResponse(_Base):
    data: OpportunityDetail
    meta: Meta
