from fastapi import APIRouter, Depends, Request

from app.core.dependencies import get_current_athlete
from app.core.response import success_response
from app.modules.identity.profile_schema import (
    AthleteExperienceCreateInput,
    AthleteExperiencePatchInput,
    AthleteOnboardingProfileInput,
    AthletePhysicalEditInput,
    AthleteProfilePatch,
    AthleteProfileResponse,
    AthleteSportEditInput,
)
from app.modules.identity.profile_service import ProfileService


router = APIRouter(
    prefix="/v1/me/profile",
    tags=["M1 - Athlete Profile"],
)


profile_service = ProfileService()


@router.get(
    "/athlete",
    response_model=dict,
    summary="Get authenticated athlete profile",
    description="Returns the profile overview for the authenticated athlete.",
)
def get_my_athlete_profile(
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.get_my_profile(
        current_user["user_id"]
    )

    request_id = getattr(request.state, "request_id", None)

    return success_response(
        profile.model_dump(mode="json"),
        request_id=request_id,
    )


@router.put(
    "/athlete",
    response_model=dict,
    summary="Save authenticated athlete onboarding profile",
    description="Creates or updates the authenticated athlete's M1 profile.",
)
def save_my_athlete_profile(
    payload: AthleteOnboardingProfileInput,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.save_onboarding_profile(
        current_user["user_id"],
        payload,
    )
    request_id = getattr(request.state, "request_id", None)
    return success_response(
        profile.model_dump(mode="json"),
        request_id=request_id,
    )


@router.patch(
    "/athlete",
    response_model=dict,
    summary="Partially update authenticated athlete profile",
)
def patch_my_athlete_profile(
    payload: AthleteProfilePatch,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.patch_my_profile(
        current_user["user_id"], payload
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.put("/athlete/sports/{sport_id}", response_model=dict)
def put_my_athlete_sport(
    sport_id: str,
    payload: AthleteSportEditInput,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.put_my_sport(
        current_user["user_id"], sport_id, payload
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.post("/athlete/sports/{sport_id}/primary", response_model=dict)
def set_my_primary_sport(
    sport_id: str,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.set_primary_sport(
        current_user["user_id"], sport_id
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.delete("/athlete/sports/{sport_id}", response_model=dict)
def delete_my_athlete_sport(
    sport_id: str,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.delete_my_sport(
        current_user["user_id"], sport_id
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.patch("/athlete/physical", response_model=dict)
def patch_my_physical_profile(
    payload: AthletePhysicalEditInput,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.patch_my_physical(
        current_user["user_id"], payload
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.post("/athlete/experience", response_model=dict)
def create_my_experience(
    payload: AthleteExperienceCreateInput,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.create_my_experience(
        current_user["user_id"], payload
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.patch("/athlete/experience/{experience_id}", response_model=dict)
def patch_my_experience(
    experience_id: str,
    payload: AthleteExperiencePatchInput,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.patch_my_experience(
        current_user["user_id"], experience_id, payload
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )


@router.delete("/athlete/experience/{experience_id}", response_model=dict)
def delete_my_experience(
    experience_id: str,
    request: Request,
    current_user: dict = Depends(get_current_athlete),
):
    profile = profile_service.delete_my_experience(
        current_user["user_id"], experience_id
    )
    return success_response(
        profile.model_dump(mode="json"),
        request_id=getattr(request.state, "request_id", None),
    )
