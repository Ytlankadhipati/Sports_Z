from datetime import date
import re
import secrets
from typing import Any
from uuid import uuid4

from fastapi import HTTPException

from app.core.errors import not_found
from app.modules.identity.profile_repository import ProfileRepository
from app.modules.identity.profile_schema import (
    AthleteProfileResponse,
    AthleteOnboardingProfileInput,
    AthleteProfilePatch,
    AthleteSportEditInput,
    ExperienceItem,
    AthleteExperienceCreateInput,
    AthleteExperiencePatchInput,
    AthletePhysicalEditInput,
    PhysicalStats,
    PrivacySettings,
    SportProfile,
)


class ProfileService:

    def __init__(self) -> None:
        self.repository = ProfileRepository()

    def get_my_profile(self, user_id: str) -> AthleteProfileResponse:

        profile = self.repository.get_by_user_id(user_id)

        if not profile:
            raise not_found(
                "Athlete profile has not been created yet"
            )

        sports_id_doc = self.repository.get_sportsz_id(user_id)

        sportsz_id = (
            sports_id_doc.get("sportsz_id")
            if sports_id_doc
            else None
        )

        sports_source = profile.get(
            "sport_profiles",
            profile.get("sports", []),
        )

        sports = []
        for item in sports_source:
            s_id = str(item.get("sport_id", ""))
            s_name = item.get("sport_name")
            if not s_name and s_id:
                sport_doc = self.repository.get_sport_by_id(s_id)
                if sport_doc:
                    s_name = sport_doc.get("name")
            sports.append(
                SportProfile(
                    sport_id=s_id,
                    sport_name=s_name,
                    is_primary=bool(item.get("is_primary", False)),
                    positions=item.get("positions", []),
                    level=item.get("level"),
                    attributes=item.get("attributes", {}),
                )
            )

        physical_data = profile.get("physical")

        physical = (
            PhysicalStats(
                height_cm=physical_data.get("height_cm"),
                weight_kg=physical_data.get("weight_kg"),
                dominant_hand=physical_data.get("dominant_hand"),
                measured_at=physical_data.get("measured_at"),
            )
            if physical_data
            else None
        )

        experience = []
        for item in profile.get("experience", []):
            org_id = item.get("organization_id")
            org_name = item.get("organization_name") or item.get("organization")
            if not org_name and org_id:
                org_doc = self.repository.get_organization_by_id(str(org_id))
                if org_doc:
                    org_name = org_doc.get("name")
            experience.append(
                ExperienceItem(
                    id=str(item.get("id", "")),
                    title=item.get("title", ""),
                    organization_id=str(org_id) if org_id is not None else None,
                    organization_name=org_name,
                    started_year=item.get("started_year"),
                    ended_year=item.get("ended_year"),
                    description=item.get("description"),
                )
            )

        privacy_data = profile.get("privacy")

        privacy = (
            PrivacySettings(**privacy_data)
            if privacy_data
            else None
        )

        completion = self._calculate_completion(
            profile=profile,
            sportsz_id=sportsz_id,
        )

        return AthleteProfileResponse(
            user_id=user_id,
            sportsz_id=sportsz_id,
            full_name=profile.get("full_name"),
            date_of_birth=profile.get("date_of_birth"),
            gender=profile.get("gender"),
            city=profile.get("city"),
            region=profile.get("region"),
            bio=profile.get("bio"),
            photo_url=profile.get("photo_url"),
            cover_photo_url=None,  # Integration TODO: M5 media module owns cover uploads
            sports=sports,
            physical=physical,
            experience=experience,
            privacy=privacy,
            completion=completion,
        )

    def save_onboarding_profile(
        self,
        user_id: str,
        payload: AthleteOnboardingProfileInput,
    ) -> AthleteProfileResponse:
        """Create or update only client-editable M1 onboarding fields."""
        fields = payload.model_dump(mode="json", exclude={"sports"})
        fields["sports"] = [
            {
                "sport_id": self._sport_key(sport.sport_name),
                "sport_name": sport.sport_name.strip(),
                "is_primary": index == 0,
                "positions": sport.positions,
                "level": sport.level,
                "attributes": {},
            }
            for index, sport in enumerate(payload.sports)
        ]

        sports_id = self.repository.get_sportsz_id(user_id)
        if not sports_id:
            for _ in range(10):
                candidate = self._new_sportsz_id()
                if self.repository.add_sportsz_id_if_missing(user_id, candidate):
                    break
                sports_id = self.repository.get_sportsz_id(user_id)
                if sports_id:
                    break
            else:
                raise RuntimeError("Could not allocate athlete SportsZ ID")

        self.repository.upsert_onboarding_profile(user_id, fields)
        return self.get_my_profile(user_id)

    def patch_my_profile(
        self, user_id: str, payload: AthleteProfilePatch
    ) -> AthleteProfileResponse:
        """Apply a sparse onboarding update without replacing later-step data."""
        fields = payload.model_dump(mode="json", exclude_unset=True)
        sports = fields.pop("sports", None)
        if sports is not None:
            normalized_sports = []
            for index, item in enumerate(sports):
                sport_id = item.get("sport_id")
                sport_doc = (
                    self.repository.get_sport_by_id(sport_id)
                    if sport_id
                    else None
                )
                if not sport_doc or sport_doc.get("name") != item["sport_name"]:
                    raise HTTPException(
                        status_code=422,
                        detail="Choose a sport from the published SportsZ catalog",
                    )
                normalized_sports.append(
                    {
                        "sport_id": sport_id,
                        "sport_name": sport_doc["name"],
                        "is_primary": index == 0,
                        "positions": item.get("positions", []),
                        "level": item.get("level"),
                        "attributes": {},
                    }
                )
            fields["sports"] = normalized_sports
        self.repository.upsert_onboarding_profile(user_id, fields)

        # The ID is issued once a real sport selection is saved, and remains
        # server-owned and immutable for this user.
        if sports:
            self._ensure_sportsz_id(user_id)
        return self.get_my_profile(user_id)

    def put_my_sport(
        self,
        user_id: str,
        sport_id: str,
        payload: AthleteSportEditInput,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        sport = self.repository.get_active_sport_by_id(sport_id)
        if not sport:
            raise not_found("Sport was not found in the active SportsZ catalog")

        field = self._sports_field(profile)
        current = list(profile.get(field, []))
        existing_index = next(
            (index for index, item in enumerate(current) if item.get("sport_id") == sport_id),
            None,
        )
        existing = current[existing_index] if existing_index is not None else None
        if existing is None:
            is_primary = not current
            attributes = {}
        else:
            is_primary = bool(existing.get("is_primary", False))
            attributes = existing.get("attributes", {})

        updated = {
            "sport_id": sport_id,
            "sport_name": sport["name"],
            "is_primary": is_primary,
            "positions": payload.positions,
            "level": payload.level,
            "attributes": attributes,
        }
        if existing_index is None:
            current.append(updated)
        else:
            current[existing_index] = updated
        if not any(item.get("is_primary") for item in current):
            current[0]["is_primary"] = True
        if not self.repository.replace_sports(user_id, current, field=field):
            raise not_found("Athlete profile has not been created yet")
        self._ensure_sportsz_id(user_id)
        return self.get_my_profile(user_id)

    def set_primary_sport(
        self,
        user_id: str,
        sport_id: str,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        field = self._sports_field(profile)
        sports = list(profile.get(field, []))
        if not any(item.get("sport_id") == sport_id for item in sports):
            raise not_found("Athlete sport was not found")
        sports = [
            {**item, "is_primary": item.get("sport_id") == sport_id}
            for item in sports
        ]
        if not self.repository.replace_sports(user_id, sports, field=field):
            raise not_found("Athlete profile has not been created yet")
        return self.get_my_profile(user_id)

    def delete_my_sport(
        self,
        user_id: str,
        sport_id: str,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        field = self._sports_field(profile)
        sports = list(profile.get(field, []))
        removed = next(
            (item for item in sports if item.get("sport_id") == sport_id),
            None,
        )
        if removed is None:
            raise not_found("Athlete sport was not found")
        sports = [item for item in sports if item.get("sport_id") != sport_id]
        if sports and (
            removed.get("is_primary") or not any(item.get("is_primary") for item in sports)
        ):
            sports = [
                {**item, "is_primary": index == 0}
                for index, item in enumerate(sports)
            ]
        if not self.repository.replace_sports(user_id, sports, field=field):
            raise not_found("Athlete profile has not been created yet")
        return self.get_my_profile(user_id)

    def patch_my_physical(
        self,
        user_id: str,
        payload: AthletePhysicalEditInput,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        physical = dict(profile.get("physical") or {})
        physical.update(payload.model_dump(mode="json", exclude_unset=True))
        if any(
            physical.get(field) is not None
            for field in ("height_cm", "weight_kg", "dominant_hand")
        ):
            physical["measured_at"] = date.today().isoformat()
        else:
            physical = {}
        if not self.repository.set_physical(user_id, physical):
            raise not_found("Athlete profile has not been created yet")
        return self.get_my_profile(user_id)

    def create_my_experience(
        self,
        user_id: str,
        payload: AthleteExperienceCreateInput,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        experience = list(profile.get("experience", []))
        item = payload.model_dump(mode="json")
        item["id"] = uuid4().hex
        organization_id = item.get("organization_id")
        organization = (
            self.repository.get_active_organization_by_id(organization_id)
            if organization_id
            else None
        )
        if organization_id and not organization:
            raise not_found("Organization was not found")
        item["organization_name"] = organization.get("name") if organization else None
        experience.append(item)
        if not self.repository.replace_experience(user_id, experience):
            raise not_found("Athlete profile has not been created yet")
        return self.get_my_profile(user_id)

    def patch_my_experience(
        self,
        user_id: str,
        experience_id: str,
        payload: AthleteExperiencePatchInput,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        experience = list(profile.get("experience", []))
        index = next(
            (i for i, item in enumerate(experience) if item.get("id") == experience_id),
            None,
        )
        if index is None:
            raise not_found("Experience was not found")
        updated = dict(experience[index])
        fields = payload.model_dump(mode="json", exclude_unset=True)
        organization_id = fields.get("organization_id", updated.get("organization_id"))
        if "organization_id" in fields:
            organization = (
                self.repository.get_active_organization_by_id(organization_id)
                if organization_id
                else None
            )
            if organization_id and not organization:
                raise not_found("Organization was not found")
            fields["organization_name"] = organization.get("name") if organization else None
        updated.update(fields)
        started = updated.get("started_year")
        ended = updated.get("ended_year")
        if started is not None and ended is not None and ended < started:
            raise HTTPException(
                status_code=422,
                detail="Experience end year must be on or after its start year",
            )
        experience[index] = updated
        if not self.repository.replace_experience(user_id, experience):
            raise not_found("Athlete profile has not been created yet")
        return self.get_my_profile(user_id)

    def delete_my_experience(
        self,
        user_id: str,
        experience_id: str,
    ) -> AthleteProfileResponse:
        profile = self.repository.get_by_user_id(user_id)
        if not profile:
            raise not_found("Athlete profile has not been created yet")
        experience = list(profile.get("experience", []))
        remaining = [item for item in experience if item.get("id") != experience_id]
        if len(remaining) == len(experience):
            raise not_found("Experience was not found")
        if not self.repository.replace_experience(user_id, remaining):
            raise not_found("Athlete profile has not been created yet")
        return self.get_my_profile(user_id)

    @staticmethod
    def _sports_field(profile: dict[str, Any]) -> str:
        return "sport_profiles" if "sport_profiles" in profile else "sports"

    def _ensure_sportsz_id(self, user_id: str) -> None:
        if self.repository.get_sportsz_id(user_id):
            return
        for _ in range(10):
            if self.repository.add_sportsz_id_if_missing(
                user_id, self._new_sportsz_id()
            ):
                return
            if self.repository.get_sportsz_id(user_id):
                return
        raise RuntimeError("Could not allocate athlete SportsZ ID")

    @staticmethod
    def _sport_key(sport_name: str) -> str:
        key = re.sub(r"[^a-z0-9]+", "-", sport_name.strip().lower()).strip("-")
        return key or "sport"

    @staticmethod
    def _new_sportsz_id() -> str:
        alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        first = "".join(secrets.choice(alphabet) for _ in range(4))
        second = "".join(secrets.choice(alphabet) for _ in range(4))
        return f"SZ-{first}-{second}"

    @staticmethod
    def _calculate_completion(
        *,
        profile: dict[str, Any],
        sportsz_id: str | None,
    ) -> int:
        """
        Conservative M1 profile completion calculation.

        NOTE (Implementation Gap):
        Detailed, weighted completion scoring is assigned to Sprint 3 (S3)
        under platform_config / ProfileCacheService (M1/M4).
        Until production completion weights are approved in platform_config,
        this method evaluates presence of core profile sections without
        inventing unapproved production weights.
        """

        checks = [
            bool(profile.get("full_name")),
            bool(profile.get("date_of_birth")),
            bool(profile.get("gender")),
            bool(profile.get("city")),
            bool(profile.get("bio")),
            bool(profile.get("sport_profiles", profile.get("sports", []))),
            bool(profile.get("physical")),
            bool(profile.get("experience")),
            bool(sportsz_id),
        ]

        completed = sum(checks)

        return round((completed / len(checks)) * 100)
