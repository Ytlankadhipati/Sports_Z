import os

import firebase_admin
from dotenv import load_dotenv
from fastapi import HTTPException, status
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials

from app.core.database import users_collection
from app.core.security import create_access_token


load_dotenv()


# Firebase Admin SDK ek hi baar initialize hoga
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")

if not FIREBASE_CREDENTIALS_PATH:
    raise RuntimeError(
        "FIREBASE_CREDENTIALS_PATH is not configured"
    )


if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)


def verify_firebase_token(id_token: str) -> dict:
    """
    Flutter se aaya Firebase ID token verify karta hai.

    Valid token hone par:
    - MongoDB me user find/create karta hai
    - Existing application JWT generate karta hai

    NOTE:
    Ye existing authentication flow ko preserve karta hai.
    """

    try:
        decoded_token = firebase_auth.verify_id_token(id_token)

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase token",
        )

    firebase_uid = decoded_token.get("uid")
    email = decoded_token.get("email")

    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token me UID nahi mila",
        )

    # MongoDB me existing user check karo
    user = users_collection.find_one(
        {"firebase_uid": firebase_uid}
    )

    if not user:
        # New user
        user_doc = {
            "firebase_uid": firebase_uid,
            "email": email,
            "role": None,
        }

        result = users_collection.insert_one(user_doc)

        user_id = str(result.inserted_id)
        role = None

    else:
        user_id = str(user["_id"])
        role = user.get("role")

    # Existing application JWT
    token = create_access_token(
        {
            "sub": user_id,
            "role": role or "unassigned",
        }
    )

    return {
        "token": token,
        "user_id": user_id,
        "role": role,
    }


def set_user_role(user_id: str, role: str) -> dict:
    """
    Existing role-selection flow.

    IMPORTANT:
    Is function ko next security step me authenticated
    current user ke saath replace karna hai.
    """

    from bson import ObjectId

    try:
        object_id = ObjectId(user_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user ID",
        )

    result = users_collection.update_one(
        {"_id": object_id},
        {"$set": {"role": role}},
    )

    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    token = create_access_token(
        {
            "sub": user_id,
            "role": role,
        }
    )

    return {
        "token": token,
        "user_id": user_id,
        "role": role,
    }


def resolve_firebase_user(id_token: str) -> dict:
    """
    Firebase ID token verify karke MongoDB se
    current application user resolve karta hai.

    Ye authenticated API dependencies ke liye use hoga.
    """

    try:
        decoded_token = firebase_auth.verify_id_token(id_token)

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase token",
        )

    firebase_uid = decoded_token.get("uid")

    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase UID not found in token",
        )

    user = users_collection.find_one(
        {"firebase_uid": firebase_uid}
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    firebase_info = decoded_token.get("firebase") or {}
    claims = {
        "email": decoded_token.get("email"),
        "email_verified": bool(decoded_token.get("email_verified")),
        "phone_number": decoded_token.get("phone_number"),
        "providers": list((firebase_info.get("identities") or {}).keys()),
    }

    return {
        "user_id": str(user["_id"]),
        "firebase_uid": firebase_uid,
        "role": user.get("role"),
        "claims": claims,
    }