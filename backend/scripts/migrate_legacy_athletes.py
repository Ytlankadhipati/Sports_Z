"""Dry-run-first, idempotent backfill from legacy athletes to M1 collections."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import date
from typing import Any

from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.core.database import (
    athlete_profiles_collection,
    db,
    sports_ids_collection,
    users_collection,
)
from app.modules.identity.profile_service import ProfileService


legacy_athletes = db["athletes"]


def _to_profile(athlete: dict[str, Any], user_id: str) -> dict[str, Any] | None:
    name = athlete.get("full_name")
    if not isinstance(name, str) or not name.strip():
        return None

    profile: dict[str, Any] = {"user_id": user_id, "full_name": name.strip()}
    dob = athlete.get("dob")
    if isinstance(dob, str):
        try:
            profile["date_of_birth"] = date.fromisoformat(dob).isoformat()
        except ValueError:
            pass

    gender = athlete.get("gender")
    if isinstance(gender, str) and gender.strip():
        profile["gender"] = gender.strip()

    # Legacy height/weight fields have no units, so do not guess cm/kg.
    # `dominant_side` is unit-free and maps directly to the M1 dominant hand.
    physical_info = athlete.get("physical_info")
    if isinstance(physical_info, dict):
        dominant = physical_info.get("dominant_side")
        if isinstance(dominant, str) and dominant.strip():
            profile["physical"] = {"dominant_hand": dominant.strip()}

    sports = athlete.get("sports")
    if isinstance(sports, list):
        mapped_sports = []
        for item in sports:
            if not isinstance(item, dict):
                continue
            sport_name = item.get("sport")
            if not isinstance(sport_name, str) or not sport_name.strip():
                continue
            positions = [item["specialization"].strip()] if isinstance(
                item.get("specialization"), str
            ) and item["specialization"].strip() else []
            attributes = {
                key: item[key]
                for key in ("category", "event")
                if isinstance(item.get(key), str) and item[key].strip()
            }
            mapped_sports.append(
                {
                    "sport_id": ProfileService._sport_key(sport_name),
                    "sport_name": sport_name.strip(),
                    "is_primary": len(mapped_sports) == 0,
                    "positions": positions,
                    "level": None,
                    "attributes": attributes,
                }
            )
        if mapped_sports:
            profile["sports"] = mapped_sports

    return profile


def plan_migration() -> tuple[list[tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]], dict[str, int]]:
    athletes = list(legacy_athletes.find({}))
    legacy_user_ref_counts = Counter(
        str(athlete.get("user_id")) for athlete in athletes if athlete.get("user_id") is not None
    )
    counts = {
        "users": users_collection.count_documents({}),
        "athletes": len(athletes),
        "athlete_profiles": athlete_profiles_collection.count_documents({}),
        "sports_ids": sports_ids_collection.count_documents({}),
        "safely_mappable": 0,
        "ambiguous_or_invalid": 0,
        "profiles_to_insert": 0,
        "profiles_already_present": 0,
        "sports_ids_to_link": 0,
        "sports_ids_already_linked": 0,
        "sports_ids_ambiguous_or_invalid": 0,
    }
    plan = []

    for athlete in athletes:
        legacy_user_id = athlete.get("user_id")
        if isinstance(legacy_user_id, str) and ObjectId.is_valid(legacy_user_id):
            legacy_user_id = ObjectId(legacy_user_id)
        if not isinstance(legacy_user_id, ObjectId):
            counts["ambiguous_or_invalid"] += 1
            continue
        if legacy_user_ref_counts[str(legacy_user_id)] != 1:
            counts["ambiguous_or_invalid"] += 1
            continue

        user = users_collection.find_one({"_id": legacy_user_id}, {"role": 1})
        if not user or user.get("role") != "athlete":
            counts["ambiguous_or_invalid"] += 1
            continue

        user_id = str(legacy_user_id)
        profile = _to_profile(athlete, user_id)
        if profile is None:
            counts["ambiguous_or_invalid"] += 1
            continue

        linked_ids = list(sports_ids_collection.find({"athlete_id": athlete["_id"]}))
        counts["safely_mappable"] += 1
        if athlete_profiles_collection.find_one({"user_id": user_id}, {"_id": 1}):
            counts["profiles_already_present"] += 1
        else:
            counts["profiles_to_insert"] += 1

        linkable_ids = []
        if len(linked_ids) == 1:
            id_doc = linked_ids[0]
            code = id_doc.get("sports_id_code")
            if isinstance(code, str) and code.strip():
                conflicting = sports_ids_collection.find_one(
                    {"sportsz_id": code.strip(), "_id": {"$ne": id_doc["_id"]}},
                    {"_id": 1},
                )
                if not conflicting:
                    has_conflicting_owner = (
                        id_doc.get("user_id") is not None
                        and id_doc.get("user_id") != user_id
                    )
                    has_conflicting_code = (
                        id_doc.get("sportsz_id") is not None
                        and id_doc.get("sportsz_id") != code.strip()
                    )
                    if has_conflicting_owner or has_conflicting_code:
                        counts["sports_ids_ambiguous_or_invalid"] += 1
                    elif id_doc.get("user_id") == user_id and id_doc.get("sportsz_id") == code.strip():
                        counts["sports_ids_already_linked"] += 1
                        linkable_ids.append(id_doc)
                    else:
                        counts["sports_ids_to_link"] += 1
                        linkable_ids.append(id_doc)
                else:
                    counts["sports_ids_ambiguous_or_invalid"] += 1
            else:
                counts["sports_ids_ambiguous_or_invalid"] += 1
        elif len(linked_ids) > 1:
            counts["sports_ids_ambiguous_or_invalid"] += 1

        plan.append((athlete, profile, linkable_ids))

    return plan, counts


def apply_plan(plan: list[tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]]) -> dict[str, int]:
    applied = {"profiles_inserted": 0, "profiles_skipped": 0, "sports_ids_linked": 0, "sports_ids_skipped": 0}
    for athlete, profile, linked_ids in plan:
        user_id = profile["user_id"]
        try:
            result = athlete_profiles_collection.update_one(
                {"user_id": user_id}, {"$setOnInsert": profile}, upsert=True
            )
            if result.upserted_id is not None:
                applied["profiles_inserted"] += 1
            else:
                applied["profiles_skipped"] += 1
        except DuplicateKeyError:
            applied["profiles_skipped"] += 1

        if len(linked_ids) != 1:
            applied["sports_ids_skipped"] += 1
            continue

        id_doc = linked_ids[0]
        code = id_doc.get("sports_id_code")
        if not isinstance(code, str) or not code.strip():
            applied["sports_ids_skipped"] += 1
            continue
        code = code.strip()
        try:
            result = sports_ids_collection.update_one(
                {
                    "_id": id_doc["_id"],
                    "$or": [
                        {"user_id": {"$exists": False}},
                        {"user_id": user_id},
                    ],
                },
                {"$set": {"user_id": user_id, "sportsz_id": code}},
            )
            if result.modified_count or sports_ids_collection.find_one(
                {"_id": id_doc["_id"], "user_id": user_id, "sportsz_id": code}, {"_id": 1}
            ):
                applied["sports_ids_linked"] += 1
            else:
                applied["sports_ids_skipped"] += 1
        except DuplicateKeyError:
            applied["sports_ids_skipped"] += 1

    return applied


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Apply the reviewed idempotent backfill")
    args = parser.parse_args()

    plan, counts = plan_migration()
    print("preflight", counts)
    if not args.apply:
        print("dry_run", True)
        return
    print("applied", apply_plan(plan))


if __name__ == "__main__":
    main()
