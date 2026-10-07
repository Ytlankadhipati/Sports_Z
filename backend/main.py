from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import client, ensure_indexes
from app.core.errors import register_error_handlers
from app.modules.identity import auth_router
from app.modules.identity import profile_router
from app.modules.identity import sports_router
from app.modules.opportunities import router as opportunities_router
from app.modules.events import router as events_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    client.admin.command("ping")
    ensure_indexes()
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
app.include_router(opportunities_router.router)
app.include_router(events_router.router)


@app.get("/")
def read_root():
    return {"message": "SportsZ backend is running!"}
