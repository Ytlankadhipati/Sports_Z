import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from fastapi import HTTPException, status
from app.core.database import users_collection
from app.core.security import create_access_token
import os
from dotenv import load_dotenv

load_dotenv()

# Firebase Admin SDK ek hi baar initialize hoga
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")

if not firebase_admin._apps:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)


def verify_firebase_token(id_token: str) -> dict:
    """
    Flutter se aaya Firebase ID token verify karta hai.
    Agar valid hai, MongoDB me user ko find/create karta hai,
    aur apna JWT bana ke deta hai.
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

    # Check karo user MongoDB me pehle se hai ya nahi
    user = users_collection.find_one({"firebase_uid": firebase_uid})

    if not user:
        # Naya user — role abhi None rahega, role_selection screen se set hoga
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

    token = create_access_token({"sub": user_id, "role": role or "unassigned"})
    return {"token": token, "user_id": user_id, "role": role}


def set_user_role(user_id: str, role: str) -> dict:
    """Role selection screen se role set/update karta hai."""
    from bson import ObjectId

    users_collection.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"role": role}},
    )
    token = create_access_token({"sub": user_id, "role": role})
    return {"token": token, "user_id": user_id, "role": role}