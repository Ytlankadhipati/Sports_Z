from fastapi import FastAPI
from app.routers import auth_router

app = FastAPI(title="SportsZ API", version="1.0.0")

app.include_router(auth_router.router)


@app.get("/")
def read_root():
    return {"message": "SportsZ backend is running!"}