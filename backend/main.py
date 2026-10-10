from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import client, ensure_indexes
from app.core.errors import register_error_handlers
from app.modules.identity import auth_router
from app.modules.identity import profile_router
from app.modules.identity import sports_router
from app.modules.identity import organizations_router
from app.modules.identity import sportsz_id_router
from app.modules.opportunities import router as opportunities_router
from app.modules.events import router as events_router
from app.modules.discovery import router as saved_router
from app.modules.events.repository import ensure_indexes as ensure_event_indexes
from app.modules.discovery.repository import ensure_indexes as ensure_saved_indexes


@asynccontextmanager
async def lifespan(_: FastAPI):
    client.admin.command("ping")
    ensure_indexes()
    ensure_event_indexes()
    ensure_saved_indexes()
    yield


app = FastAPI(title="SportsZ API", version="1.0.0", lifespan=lifespan)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Development ke liye sab allow, production me specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


register_error_handlers(app)


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = str(uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


app.include_router(auth_router.router)
app.include_router(profile_router.router)
app.include_router(sports_router.router)
app.include_router(organizations_router.router)
app.include_router(sportsz_id_router.router)
app.include_router(opportunities_router.router)
app.include_router(events_router.router)
app.include_router(saved_router.router)


@app.get("/")
def read_root():
    return {"message": "SportsZ backend is running!"}
