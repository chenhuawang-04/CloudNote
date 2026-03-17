"""Server settings management routes."""

from __future__ import annotations

from pydantic import BaseModel
from fastapi import APIRouter

from ..config import get_config, update_ai_config

router = APIRouter(tags=["settings"])


class AISettingsOut(BaseModel):
    base_url: str
    api_key_set: bool  # Don't expose the full key
    api_key_preview: str  # Show last 4 chars
    model: str


class AISettingsUpdate(BaseModel):
    base_url: str | None = None
    api_key: str | None = None
    model: str | None = None


@router.get("/settings/ai", response_model=AISettingsOut)
async def get_ai_settings():
    cfg = get_config()
    key = cfg.ai.api_key
    return AISettingsOut(
        base_url=cfg.ai.base_url,
        api_key_set=bool(key),
        api_key_preview=f"****{key[-4:]}" if len(key) >= 4 else ("****" if key else ""),
        model=cfg.ai.model,
    )


@router.put("/settings/ai", response_model=AISettingsOut)
async def update_ai_settings(body: AISettingsUpdate):
    update_ai_config(
        base_url=body.base_url,
        api_key=body.api_key,
        model=body.model,
    )
    cfg = get_config()
    key = cfg.ai.api_key
    return AISettingsOut(
        base_url=cfg.ai.base_url,
        api_key_set=bool(key),
        api_key_preview=f"****{key[-4:]}" if len(key) >= 4 else ("****" if key else ""),
        model=cfg.ai.model,
    )
