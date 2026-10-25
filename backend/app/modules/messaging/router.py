"""M4 messaging routes (M01-M05). Thin: rules live in rules.py / service.py."""

from __future__ import annotations

from typing import Callable

from fastapi import APIRouter, Depends, Query, Request, Response

from app.core.authz import ViewerContext
from app.core.authz.deps import get_viewer_context
from app.core.response import success_response
from app.modules.messaging.schemas import ConversationCreate, MessageCreate, MuteUpdate
from app.modules.relationships.container import M4Container, get_container
from app.modules.relationships.errors import DomainError, to_http

router = APIRouter(prefix="/v1/conversations", tags=["M4 - Messaging"])


def _rid(request: Request):
    return getattr(request.state, "request_id", None)


def _run(fn: Callable, *a, **k):
    try:
        return fn(*a, **k)
    except DomainError as exc:
        raise to_http(exc)


@router.get("")
def list_conversations(request: Request, q: str | None = Query(None, max_length=80),
                       limit: int = Query(20, ge=1, le=50), cursor: str | None = None,
                       viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    items, nxt = _run(c.messaging.list_conversations, viewer, limit, cursor, q)
    return success_response(items, request_id=_rid(request), next_cursor=nxt)


@router.post("", status_code=201)
def start_conversation(body: ConversationCreate, request: Request,
                       viewer: ViewerContext = Depends(get_viewer_context),
                       c: M4Container = Depends(get_container)):
    return success_response(_run(c.messaging.start, viewer, body.recipient_user_id, body.text),
                            request_id=_rid(request))


@router.get("/{conversation_id}/messages")
def list_messages(conversation_id: str, request: Request, limit: int = Query(30, ge=1, le=100),
                  cursor: str | None = None, viewer: ViewerContext = Depends(get_viewer_context),
                  c: M4Container = Depends(get_container)):
    data, nxt = _run(c.messaging.list_messages, viewer, conversation_id, limit, cursor)
    return success_response(data, request_id=_rid(request), next_cursor=nxt)


@router.post("/{conversation_id}/messages", status_code=201)
def send_message(conversation_id: str, body: MessageCreate, request: Request,
                 viewer: ViewerContext = Depends(get_viewer_context),
                 c: M4Container = Depends(get_container)):
    return success_response(_run(c.messaging.send, viewer, conversation_id, body.text), request_id=_rid(request))


@router.post("/{conversation_id}/read", status_code=204)
def mark_read(conversation_id: str, viewer: ViewerContext = Depends(get_viewer_context),
              c: M4Container = Depends(get_container)):
    _run(c.messaging.mark_read, viewer, conversation_id)
    return Response(status_code=204)


@router.patch("/{conversation_id}/mute")
def mute(conversation_id: str, body: MuteUpdate, request: Request,
         viewer: ViewerContext = Depends(get_viewer_context), c: M4Container = Depends(get_container)):
    return success_response(_run(c.messaging.set_mute, viewer, conversation_id, body.muted),
                            request_id=_rid(request))


@router.delete("/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: str, viewer: ViewerContext = Depends(get_viewer_context),
                        c: M4Container = Depends(get_container)):
    _run(c.messaging.delete_for_me, viewer, conversation_id)
    return Response(status_code=204)
