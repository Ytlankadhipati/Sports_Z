"""M4 seed CLI.

  python -m scripts.seed_m4 seed     # create/refresh fixtures + platform_config defaults + M4 indexes
  python -m scripts.seed_m4 reset    # delete M4 data that involves fixture users
  python -m scripts.seed_m4 list     # print fixture name -> user_id

Run from the backend/ folder. Needs the same .env as the API (MONGO_URI, MONGO_DB_NAME).
"""

from __future__ import annotations

import sys


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "seed"
    from app.core.database import athlete_profiles_collection, db, users_collection
    from app.devtools.fixtures import reset_fixture_data, seed_fixtures
    from app.modules.relationships.container import get_container

    container = get_container()
    if cmd == "seed":
        container.ensure_indexes()
        container.config.seed_defaults()
        ids = seed_fixtures(users_collection, athlete_profiles_collection)
    elif cmd == "reset":
        ids = seed_fixtures(users_collection, athlete_profiles_collection)
        print("deleted:", reset_fixture_data(db, ids))
    elif cmd == "list":
        ids = seed_fixtures(users_collection, athlete_profiles_collection)
    else:
        print(__doc__)
        return 2
    for name, uid in ids.items():
        print(f"{name:13} {uid}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
