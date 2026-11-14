"""project(): return ONLY the fields this viewer may see. Default deny."""

from __future__ import annotations

from typing import Any, Mapping

from app.core.authz import field_registry as fr
from app.core.authz.authorize import Resource, resolve_audiences
from app.core.authz.viewer_context import ViewerContext


def _hidden_by_owner(resource_type: str, doc: Mapping[str, Any], field: str, audiences: frozenset[str]) -> bool:
    """Athlete privacy.field_overrides: {"bio": "hidden"}. Restrict-only."""
    if audiences & fr.PRIVILEGED:
        return False
    if field not in fr.HIDEABLE_FIELDS.get(resource_type, frozenset()):
        return False
    overrides = ((doc.get("privacy") or {}).get("field_overrides")) or {}
    return overrides.get(field) == "hidden"


def project(
    viewer: ViewerContext | None,
    doc: Mapping[str, Any],
    resource: Resource,
    *,
    public: bool = False,
) -> dict[str, Any]:
    """Filter `doc` down to the fields the viewer's audiences may see.

    `public=True` is for the unauthenticated public ID page (viewer is None).
    Unknown fields (not in the registry) are always dropped.
    """
    if public or viewer is None:
        audiences = frozenset({fr.PUBLIC})
    else:
        audiences = resolve_audiences(viewer, resource)

    out: dict[str, Any] = {}
    for key, value in doc.items():
        allowed = fr.allowed_audiences(resource.type, key)
        if not (allowed & audiences):
            continue
        if _hidden_by_owner(resource.type, doc, key, audiences):
            continue
        out[key] = value
    return out
