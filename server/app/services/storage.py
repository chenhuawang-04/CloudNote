"""Disk-level file/folder operations."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

import aiofiles

from ..config import get_config


def _root() -> Path:
    return Path(get_config().storage.root)


def ensure_folder(rel_path: str) -> Path:
    """Create a folder on disk and return its absolute path."""
    p = _root() / rel_path
    p.mkdir(parents=True, exist_ok=True)
    return p


async def save_upload(data: bytes, rel_path: str) -> Path:
    """Write uploaded bytes to disk."""
    p = _root() / rel_path
    p.parent.mkdir(parents=True, exist_ok=True)
    async with aiofiles.open(str(p), "wb") as f:
        await f.write(data)
    return p


def get_abs_path(rel_path: str) -> Path:
    return _root() / rel_path


def delete_path(disk_path: str) -> None:
    """Delete a file or directory from disk."""
    p = Path(disk_path)
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)
    elif p.is_file():
        p.unlink(missing_ok=True)


def file_size(disk_path: str) -> int:
    return os.path.getsize(disk_path)
