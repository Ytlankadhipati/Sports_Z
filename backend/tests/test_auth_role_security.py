import pytest
from pydantic import ValidationError

from app.modules.identity.auth_schema import RoleSelectionRequest


def test_role_selection_rejects_client_controlled_user_id():
    with pytest.raises(ValidationError):
        RoleSelectionRequest(role="athlete", user_id="another-user")


def test_role_selection_does_not_allow_self_assigning_admin():
    with pytest.raises(ValidationError):
        RoleSelectionRequest(role="admin")
