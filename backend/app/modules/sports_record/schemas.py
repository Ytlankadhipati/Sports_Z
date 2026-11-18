from datetime import datetime
from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field

class StrictModel(BaseModel):
    model_config=ConfigDict(extra="forbid", str_strip_whitespace=True)
class PerformanceCreate(StrictModel):
    sport_id:str=Field(min_length=1,max_length=80)
    metric_key:str=Field(min_length=1,max_length=100,pattern=r"^[a-zA-Z0-9_.-]+$")
    value:float
    unit:str=Field(min_length=1,max_length=30)
    recorded_at:datetime
    notes:str|None=Field(default=None,max_length=1000)
    evidence_media_id:str|None=None
class PerformancePatch(StrictModel):
    value:float|None=None
    unit:str|None=None
    recorded_at:datetime|None=None
    notes:str|None=Field(default=None,max_length=1000)
class AchievementCreate(StrictModel):
    title:str=Field(min_length=1,max_length=160)
    description:str|None=Field(default=None,max_length=1500)
    sport_id:str|None=None
    achievement_type:str=Field(default="general",max_length=60)
    achieved_at:datetime|None=None
    media_ids:list[str]=Field(default_factory=list,max_length=10)
class AchievementPatch(StrictModel):
    title:str|None=Field(default=None,min_length=1,max_length=160)
    description:str|None=Field(default=None,max_length=1500)
    achieved_at:datetime|None=None
class UploadRequest(StrictModel):
    filename:str=Field(min_length=1,max_length=180)
    content_type:str
    size_bytes:int=Field(gt=0,le=52428800)
    purpose:str=Field(default="evidence",max_length=40)
class ConfirmUpload(StrictModel):
    upload_id:str
class VerificationCreate(StrictModel):
    domain:Literal["identity","sport_profile","performance","achievement","document"]
    target_id:str|None=None
    document_ids:list[str]=Field(default_factory=list,max_length=10)
    note:str|None=Field(default=None,max_length=1000)
class VerificationDecision(StrictModel):
    decision:Literal["verified","rejected","needs_info","revoked"]
    reason:str=Field(min_length=3,max_length=1000)
