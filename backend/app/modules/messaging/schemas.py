from pydantic import BaseModel, ConfigDict, Field


class _In(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ConversationCreate(_In):
    recipient_user_id: str = Field(min_length=1, max_length=64)
    text: str = Field(min_length=1, max_length=5000)  # real limit from platform_config in service


class MessageCreate(_In):
    text: str = Field(min_length=1, max_length=5000)


class MuteUpdate(_In):
    muted: bool
