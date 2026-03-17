"""Utility helpers — filename sanitization, MIME detection."""

from __future__ import annotations

import mimetypes
import re
import unicodedata


def sanitize_filename(name: str) -> str:
    """Remove or replace characters unsafe for filesystems."""
    # Normalize unicode
    name = unicodedata.normalize("NFC", name)
    # Replace path separators and null bytes
    name = re.sub(r'[<>:"/\\|?*\x00]', "_", name)
    # Collapse multiple underscores / spaces
    name = re.sub(r"[_\s]+", "_", name).strip("_. ")
    return name or "unnamed"


def guess_mime(filename: str) -> str:
    """Guess MIME type from filename."""
    mime, _ = mimetypes.guess_type(filename)
    return mime or "application/octet-stream"
