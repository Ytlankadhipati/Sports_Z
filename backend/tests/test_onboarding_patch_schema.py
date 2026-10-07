import pytest
from pydantic import ValidationError

from app.modules.identity.profile_schema import AthleteProfilePatch


def test_onboarding_patch_accepts_sparse_supported_fields():
    patch = AthleteProfilePatch.model_validate({"bio": "A short introduction"})
    assert patch.model_dump(exclude_unset=True) == {"bio": "A short introduction"}


def test_onboarding_patch_rejects_server_owned_fields():
    with pytest.raises(ValidationError):
        AthleteProfilePatch.model_validate({"sportsz_id": "SZ-FAKE-1234"})


def test_onboarding_patch_accepts_supported_sections():
    patch = AthleteProfilePatch.model_validate(
        {
            "physical": {"height_cm": 182},
            "privacy": {"discoverable": False},
        }
    )
    assert patch.physical.height_cm == 182
    assert patch.privacy.discoverable is False
