"""Add a broad, alphabetical sports catalog without changing existing entries.

Run from the backend directory with the project's configured MongoDB connection:
    python -m scripts.seed_sports_catalog
"""

import re

from app.core.database import sports_collection


# A broad set of commonly practiced and internationally recognized sports.
# The catalog is intentionally data-only here; sport-specific onboarding fields
# can be added later through each sport's existing config document.
SPORT_NAMES = [
    "3x3 Basketball",
    "Alpine Skiing",
    "American Football",
    "Archery",
    "Artistic Gymnastics",
    "Artistic Swimming",
    "Athletics",
    "Badminton",
    "Bandy",
    "Baseball",
    "Basketball",
    "Beach Handball",
    "Beach Soccer",
    "Beach Volleyball",
    "Biathlon",
    "Billiards",
    "BMX Freestyle",
    "BMX Racing",
    "Bobsleigh",
    "Bodybuilding",
    "Bowling",
    "Boxing",
    "Breakdancing",
    "Canoe Slalom",
    "Canoe Sprint",
    "Chess",
    "Climbing",
    "Cricket",
    "Cross-Country Skiing",
    "Curling",
    "Cycling",
    "Darts",
    "Diving",
    "Dragon Boat Racing",
    "Equestrian",
    "Fencing",
    "Field Hockey",
    "Figure Skating",
    "Flag Football",
    "Floorball",
    "Football",
    "Freestyle Skiing",
    "Futsal",
    "Golf",
    "Greco-Roman Wrestling",
    "Handball",
    "Hang Gliding",
    "Ice Hockey",
    "Ice Skating",
    "Judo",
    "Karate",
    "Kayaking",
    "Kickboxing",
    "Kho Kho",
    "Korfball",
    "Lacrosse",
    "Luge",
    "Marathon Swimming",
    "Modern Pentathlon",
    "Motorsport",
    "Mountain Biking",
    "Muay Thai",
    "Netball",
    "Nordic Combined",
    "Open Water Swimming",
    "Padel",
    "Para Athletics",
    "Para Badminton",
    "Para Swimming",
    "Polo",
    "Powerlifting",
    "Racquetball",
    "Rhythmic Gymnastics",
    "Road Cycling",
    "Roller Skating",
    "Rowing",
    "Rugby League",
    "Rugby Sevens",
    "Rugby Union",
    "Sailing",
    "Sepak Takraw",
    "Shooting",
    "Short Track Speed Skating",
    "Skateboarding",
    "Skeleton",
    "Ski Jumping",
    "Snowboarding",
    "Softball",
    "Sport Climbing",
    "Squash",
    "Sumo",
    "Surfing",
    "Swimming",
    "Synchronized Skating",
    "Table Tennis",
    "Taekwondo",
    "Tennis",
    "Track Cycling",
    "Triathlon",
    "Volleyball",
    "Water Polo",
    "Weightlifting",
    "Wheelchair Basketball",
    "Wheelchair Rugby",
    "Wrestling",
    "Wushu",
]


def _sport_id(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def main() -> None:
    added = 0
    existing = 0
    for name in sorted(set(SPORT_NAMES), key=str.casefold):
        sport_id = _sport_id(name)
        result = sports_collection.update_one(
            {"sport_id": sport_id},
            {
                "$setOnInsert": {
                    "sport_id": sport_id,
                    "name": name,
                    "active": True,
                    "config": {"fields": []},
                }
            },
            upsert=True,
        )
        if result.upserted_id is None:
            existing += 1
        else:
            added += 1

    print(f"Sports catalog complete: {added} added, {existing} already present.")
    print(f"Catalog names sorted alphabetically: {len(set(SPORT_NAMES))}.")


if __name__ == "__main__":
    main()
