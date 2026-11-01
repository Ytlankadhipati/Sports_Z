import re
from typing import Any

from app.core.errors import not_found
from app.modules.identity.profile_repository import ProfileRepository
from app.modules.identity.public_id_schema import PublicIdData

# Same alphabet and shape as ProfileService._new_sportsz_id: SZ-XXXX-XXXX.
# (There is no check character in issued IDs, so the format is the only
# validation that can run before a database lookup.)
SPORTSZ_ID_PATTERN = re.compile(r"^SZ-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}-"
                                r"[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{4}$")

# One identical answer for malformed, unknown and disabled IDs.
_NOT_FOUND_MESSAGE = "Not found"


def is_public_page_enabled(profile: dict[str, Any]) -> bool:
    """The owner's I04 "public ID page" switch.

    No such setting exists yet (I04 settings screen and M4's privacy schema are
    not built), so every issued ID has a public page for now. When the setting
    exists, return False here and the route answers with the same 404.
    """
    return True


class PublicIdService:
    """Build the public SportsZ ID page from M1-owned records."""

    def get_public_id(self, sportsz_id: str) -> PublicIdData:
        if not SPORTSZ_ID_PATTERN.fullmatch(sportsz_id):
            raise not_found(_NOT_FOUND_MESSAGE)

        user_id = ProfileRepository.get_user_id_by_sportsz_id(sportsz_id)
        if not user_id:
            raise not_found(_NOT_FOUND_MESSAGE)

        profile = ProfileRepository.get_public_profile(user_id)
        if not profile or not is_public_page_enabled(profile):
            raise not_found(_NOT_FOUND_MESSAGE)

        sports = profile.get("sport_profiles", profile.get("sports", [])) or []
        primary = next((item for item in sports if item.get("is_primary")), None)
        if primary is None and sports:
            primary = sports[0]

        sport_name = primary.get("sport_name") if primary else None
        sport_id = primary.get("sport_id") if primary else None
        if not sport_name and sport_id:
            sport = ProfileRepository.get_sport_by_id(str(sport_id))
            sport_name = sport.get("name") if sport else None

        positions = [
            str(item).strip()
            for item in ((primary or {}).get("positions") or [])
            if str(item).strip()
        ]

        return PublicIdData(
            sportsz_id=sportsz_id,
            full_name=profile.get("full_name"),
            photo_url=profile.get("photo_url"),
            primary_sport=sport_name,
            playing_role=" \u00b7 ".join(positions) or None,
        )
