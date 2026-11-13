"""M4 demo server: try every M4 route WITHOUT Firebase, .env or a real MongoDB.

  cd backend
  pip install fastapi uvicorn mongomock pymongo
  python -m scripts.dev_m4_demo
  -> open http://127.0.0.1:8001/docs

How it works (only inside THIS process; the real app is untouched):
  * data lives in memory (mongomock) and is lost when you stop the server
  * Firebase login is replaced by a header:  X-Dev-User: ATHLETE_1
    (names: ATHLETE_1, ATHLETE_2, COACH_V, COACH_U, RECR_V, RECR_U, ORG_V, ADMIN, USER_BLOCKED)
  * GET /demo/users gives each fixture's user id (request bodies need ids)
  * the SAME services, authorize() and project() as the real API are used,
    so the rules you see here are the real rules

Not for production. Never deploy this file.
"""

from __future__ import annotations

import sys
import types


def build_app():
    # app.core.authz.deps imports M1's Firebase auth, which needs credentials.
    # Replace it with a stub BEFORE anything imports it (this process only).
    stub = types.ModuleType("app.core.dependencies")
    stub.get_current_user = lambda: {}
    sys.modules["app.core.dependencies"] = stub

    import mongomock
    from fastapi import FastAPI, Header, HTTPException
    from fastapi.responses import RedirectResponse

    from app.core.authz.deps import get_viewer_context
    from app.core.errors import register_error_handlers
    from app.core.response import success_response
    from app.devtools.fixtures import FIXTURES, seed_fixtures
    from app.devtools.router import _viewer
    from app.modules.messaging import router as messaging_router
    from app.modules.relationships import router as relationships_router
    from app.modules.relationships.container import build_container, get_container

    db = mongomock.MongoClient()["m4_demo"]
    container = build_container(db, db["users"], db["athlete_profiles"])
    container.ensure_indexes()
    container.config.seed_defaults()
    ids = seed_fixtures(db["users"], db["athlete_profiles"])

    app = FastAPI(title="SportsZ M4 demo (no Firebase)", version="demo")
    register_error_handlers(app)
    app.include_router(relationships_router.router)
    app.include_router(messaging_router.router)

    def demo_viewer(x_dev_user: str | None = Header(default=None, alias="X-Dev-User")):
        if not x_dev_user:
            raise HTTPException(401, {"code": "AUTH_REQUIRED",
                                      "message": "Send header X-Dev-User: ATHLETE_1 (or another fixture name)",
                                      "details": []})
        if x_dev_user not in FIXTURES:
            raise HTTPException(401, {"code": "AUTH_REQUIRED",
                                      "message": f"Unknown X-Dev-User. Use one of: {', '.join(FIXTURES)}",
                                      "details": []})
        return _viewer(container, db["users"], x_dev_user)

    app.dependency_overrides[get_viewer_context] = demo_viewer
    app.dependency_overrides[get_container] = lambda: container

    @app.get("/", include_in_schema=False)
    def home():
        return RedirectResponse("/docs")

    @app.get("/demo/users", tags=["demo"])
    def demo_users():
        """Fixture name -> user id. Copy an id into request bodies (target_user_id etc.)."""
        return success_response(ids)

    return app


app = build_app()

if __name__ == "__main__":
    import uvicorn

    print("\nM4 demo -> http://127.0.0.1:8001/docs   (header: X-Dev-User: ATHLETE_1)\n")
    uvicorn.run(app, host="127.0.0.1", port=8001, log_level="warning")
