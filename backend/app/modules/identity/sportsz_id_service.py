from app.core.errors import not_found
from app.modules.identity.profile_repository import ProfileRepository
from app.modules.identity.sportsz_id_schema import SportsZIdentityResponse


class SportsZIdService:
    """Build the minimal SportsZ ID view from M1-owned records."""

    def __init__(self) -> None:
        self.repository = ProfileRepository()

    def get_my_identity(self, user_id: str) -> SportsZIdentityResponse:
        sports_id = self.repository.get_sportsz_id(user_id)
        if not sports_id or not sports_id.get("sportsz_id"):
            raise not_found("SportsZ ID has not been issued yet")

        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")

        sports = profile.get("sport_profiles", profile.get("sports", [])) or []
        primary = next((item for item in sports if item.get("is_primary")), None)
        if primary is None and sports:
            primary = sports[0]

        sport_name = primary.get("sport_name") if primary else None
        sport_id = primary.get("sport_id") if primary else None
        if not sport_name and sport_id:
            sport = self.repository.get_sport_by_id(str(sport_id))
            sport_name = sport.get("name") if sport else None

        return SportsZIdentityResponse(
            sportsz_id=sports_id["sportsz_id"],
            full_name=profile.get("full_name"),
            photo_url=profile.get("photo_url"),
            primary_sport=sport_name,
            positions=list(primary.get("positions", [])) if primary else [],
            level=primary.get("level") if primary else None,
        )
