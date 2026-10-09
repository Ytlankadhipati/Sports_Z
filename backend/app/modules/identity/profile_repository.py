from typing import Any

from pymongo.collation import Collation

from app.core.database import (
    athlete_profiles_collection,
    organizations_collection,
    sports_collection,
    sports_ids_collection,
)


class ProfileRepository:

    @staticmethod
    def list_sports() -> list[dict[str, Any]]:
        return list(sports_collection.find(
            {"active": {"$ne": False}},
            {"_id": 0, "sport_id": 1, "name": 1, "icon": 1},
            collation=Collation(locale="en", strength=2),
        ).sort("name", 1))

    @staticmethod
    def get_sport_config(sport_id: str) -> dict[str, Any] | None:
        return sports_collection.find_one(
            {"sport_id": sport_id, "active": {"$ne": False}},
            {"_id": 0, "sport_id": 1, "name": 1, "config": 1},
        )

    @staticmethod
    def upsert_onboarding_profile(
        user_id: str,
        fields: dict[str, Any],
    ) -> None:
        athlete_profiles_collection.update_one(
            {"user_id": user_id},
            {
                "$set": fields,
                "$setOnInsert": {"user_id": user_id},
            },
            upsert=True,
        )

    @staticmethod
    def replace_sports(
        user_id: str,
        sports: list[dict[str, Any]],
        *,
        field: str = "sports",
    ) -> bool:
        result = athlete_profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": {field: sports}},
        )
        return result.matched_count == 1

    @staticmethod
    def set_physical(user_id: str, physical: dict[str, Any]) -> bool:
        result = athlete_profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": {"physical": physical}},
        )
        return result.matched_count == 1

    @staticmethod
    def replace_experience(
        user_id: str,
        experience: list[dict[str, Any]],
    ) -> bool:
        result = athlete_profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": {"experience": experience}},
        )
        return result.matched_count == 1

    @staticmethod
    def add_sportsz_id_if_missing(user_id: str, sportsz_id: str) -> bool:
        from pymongo.errors import DuplicateKeyError

        try:
            sports_ids_collection.insert_one(
                {"user_id": user_id, "sportsz_id": sportsz_id}
            )
            return True
        except DuplicateKeyError:
            return False

    @staticmethod
    def get_by_user_id(user_id: str) -> dict[str, Any] | None:
        return athlete_profiles_collection.find_one(
            {"user_id": user_id},
            {
                "_id": 0,
                "user_id": 1,
                "full_name": 1,
                "date_of_birth": 1,
                "gender": 1,
                "city": 1,
                "region": 1,
                "bio": 1,
                "photo_url": 1,
                "sports": 1,
                "sport_profiles": 1,
                "physical": 1,
                "experience": 1,
                "privacy": 1,
            },
        )

    @staticmethod
    def get_sportsz_id(user_id: str) -> dict[str, Any] | None:
        return sports_ids_collection.find_one(
            {"user_id": user_id},
            {
                "_id": 0,
                "sportsz_id": 1,
            },
        )

    @staticmethod
    def get_sport_by_id(sport_id: str) -> dict[str, Any] | None:
        return sports_collection.find_one(
            {"sport_id": sport_id},
            {
                "_id": 0,
                "sport_id": 1,
                "name": 1,
            },
        )

    @staticmethod
    def get_active_sport_by_id(sport_id: str) -> dict[str, Any] | None:
        return sports_collection.find_one(
            {"sport_id": sport_id, "active": {"$ne": False}},
            {"_id": 0, "sport_id": 1, "name": 1, "config": 1},
        )

    @staticmethod
    def get_organization_by_id(org_id: str) -> dict[str, Any] | None:
        return organizations_collection.find_one(
            {"public_id": org_id},
            {
                "_id": 0,
                "public_id": 1,
                "name": 1,
            },
        )

    @staticmethod
    def get_active_organization_by_id(org_id: str) -> dict[str, Any] | None:
        return organizations_collection.find_one(
            {"public_id": org_id, "active": {"$ne": False}},
            {"_id": 0, "public_id": 1, "name": 1},
        )

    @staticmethod
    def list_organizations() -> list[dict[str, Any]]:
        return list(
            organizations_collection.find(
                {"active": {"$ne": False}},
                {"_id": 0, "public_id": 1, "name": 1},
            ).sort("name", 1)
        )
