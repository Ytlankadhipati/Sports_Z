from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.modules.identity import auth_router

app = FastAPI(title="SportsZ API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Development ke liye sab allow, production me specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)


@app.get("/")
def read_root():
    return {"message": "SportsZ backend is running!"}