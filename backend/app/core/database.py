from pymongo import MongoClient
from dotenv import load_dotenv
import certifi
import os

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME")

if not MONGO_URI:
    raise RuntimeError("MONGO_URI is not configured")

if not MONGO_DB_NAME:
    raise RuntimeError("MONGO_DB_NAME is not configured")


client = MongoClient(
    MONGO_URI,
    tlsCAFile=certifi.where(),
)

db = client[MONGO_DB_NAME]


# ============================================================
# M1 — Identity, Profile & Account
# ============================================================

users_collection = db["users"]

athlete_profiles_collection = db["athlete_profiles"]

sports_collection = db["sports"]

sports_ids_collection = db["sports_ids"]

organizations_collection = db["organizations"]

organization_members_collection = db["organization_members"]


def ensure_indexes() -> None:
    """
    M1 indexes.

    This function is intentionally idempotent and can safely
    be called during application startup.
    Uses partial unique indexes to prevent failure from legacy
    documents containing null or missing values.
    """

    users_collection.create_index(
        [("firebase_uid", 1)],
        unique=True,
        partialFilterExpression={
            "firebase_uid": {
                "$type": "string"
            }
        },
        name="uq_users_firebase_uid",
    )

    athlete_profiles_collection.create_index(
        [("user_id", 1)],
        unique=True,
        name="uq_athlete_profiles_user_id",
    )

    sports_ids_collection.create_index(
        [("user_id", 1)],
        unique=True,
        partialFilterExpression={
            "user_id": {
                "$type": "string"
            }
        },
        name="uq_sports_ids_user_id",
    )

    sports_ids_collection.create_index(
        [("sportsz_id", 1)],
        unique=True,
        partialFilterExpression={
            "sportsz_id": {
                "$type": "string"
            }
        },
        name="uq_sports_ids_sportsz_id",
    )

    organizations_collection.create_index(
        [("public_id", 1)],
        unique=True,
        name="uq_organizations_public_id",
    )

    organization_members_collection.create_index(
        [("organization_id", 1), ("user_id", 1)],
        unique=True,
        name="uq_organization_members_org_user",
    )