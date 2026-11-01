from pydantic import BaseModel, ConfigDict


class PublicIdData(BaseModel):
    """Whitelist of what the public SportsZ ID page may ever return.

    Contract: docs/api/m1.yaml, contract 5. extra="forbid" plus an exact-keys
    snapshot test make sure no other field can be added by accident.
    """

    model_config = ConfigDict(extra="forbid")

    sportsz_id: str
    full_name: str | None = None
    photo_url: str | None = None
    primary_sport: str | None = None
    playing_role: str | None = None
