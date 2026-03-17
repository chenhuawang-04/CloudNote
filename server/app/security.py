"""Simple API key verification based on key.json."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

from fastapi import Header, HTTPException, status

_KEY_PATH = Path(__file__).resolve().parent.parent / "key.json"
_HEADER_NAME = "X-CloudNote-Key"


@lru_cache
def _load_key() -> str:
    if not _KEY_PATH.exists():
        raise FileNotFoundError(_KEY_PATH)

    with open(_KEY_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, str):
        key = data.strip()
        if key:
            return key

    if isinstance(data, dict):
        for field in ("key", "api_key", "secret"):
            value = data.get(field)
            if isinstance(value, str) and value.strip():
                return value.strip()

    raise ValueError("Invalid key.json format")


def verify_key(x_cloudnote_key: str | None = Header(default=None, alias=_HEADER_NAME)) -> None:
    try:
        expected = _load_key()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server key not configured. Create key.json with {\"key\": \"...\"}.",
        )

    if not x_cloudnote_key or x_cloudnote_key != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key.",
        )
