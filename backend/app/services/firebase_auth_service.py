from app.core.database import users_collection
from app.core.security import hash_password, verify_password, create_access_token
from fastapi import HTTPException, status
from bson import ObjectId


def signup_user(email: str, password: str, role: str) -> dict:
    """Naya user banata hai. Duplicate email hone par error deta hai."""
    existing_user = users_collection.find_one({"email": email})
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    hashed_pw = hash_password(password)
    user_doc = {
        "email": email,
        "password": hashed_pw,
        "role": role,
    }
    result = users_collection.insert_one(user_doc)
    user_id = str(result.inserted_id)

    token = create_access_token({"sub": user_id, "role": role})
    return {"token": token, "user_id": user_id, "role": role}


def login_user(email: str, password: str) -> dict:
    """Email/password verify karke token deta hai."""
    user = users_collection.find_one({"email": email})
    if not user or not verify_password(password, user["password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    user_id = str(user["_id"])
    role = user["role"]
    token = create_access_token({"sub": user_id, "role": role})
    return {"token": token, "user_id": user_id, "role": role}