"""Folder CRUD routes."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, HTTPException

from ..database import get_db
from ..models import FolderCreate, FolderRename, FolderOut
from ..services.storage import ensure_folder
from ..services.trash import fetch_active_folder, soft_delete_folder_tree
from ..utils.helpers import sanitize_filename

router = APIRouter(tags=["folders"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("/folders", response_model=list[FolderOut])
async def list_folders(parent_id: str | None = None):
    db = await get_db()
    if parent_id:
        rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id = ? AND deleted_at IS NULL ORDER BY name",
            (parent_id,),
        )
    else:
        rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id IS NULL AND deleted_at IS NULL ORDER BY name"
        )
    return [dict(r) for r in rows]


@router.post("/folders", response_model=FolderOut, status_code=201)
async def create_folder(body: FolderCreate):
    db = await get_db()
    folder_id = str(uuid.uuid4())
    now = _now()
    safe_name = sanitize_filename(body.name)

    # Build disk path relative to storage root
    if body.parent_id:
        parent = await fetch_active_folder(db, body.parent_id)
        if not parent:
            raise HTTPException(404, "Parent folder not found")
        rel = str(Path(parent["disk_path"]) / safe_name)
    else:
        rel = safe_name

    disk_path = str(ensure_folder(rel))

    await db.execute(
        "INSERT INTO folders (id, name, parent_id, disk_path, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (folder_id, safe_name, body.parent_id, disk_path, now, now),
    )
    await db.commit()
    return FolderOut(
        id=folder_id, name=safe_name, parent_id=body.parent_id,
        created_at=now, updated_at=now,
    )


@router.put("/folders/{folder_id}", response_model=FolderOut)
async def rename_folder(folder_id: str, body: FolderRename):
    db = await get_db()
    row = await fetch_active_folder(db, folder_id)
    if row is None:
        raise HTTPException(404, "Folder not found")

    now = _now()
    safe_name = sanitize_filename(body.name)
    await db.execute(
        "UPDATE folders SET name = ?, updated_at = ? WHERE id = ?",
        (safe_name, now, folder_id),
    )
    await db.commit()
    folder = dict(row)
    folder["name"] = safe_name
    folder["updated_at"] = now
    return folder


@router.delete("/folders/{folder_id}")
async def delete_folder(folder_id: str):
    db = await get_db()
    now = _now()
    deleted = await soft_delete_folder_tree(db, folder_id, now, now)
    if not deleted:
        raise HTTPException(404, "Folder not found")
    await db.commit()
    return {"detail": "moved_to_trash"}
