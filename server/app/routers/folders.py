"""Folder CRUD routes."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException

from ..database import get_db
from ..models import FolderCreate, FolderRename, FolderOut
from ..services.storage import ensure_folder, delete_path

router = APIRouter(tags=["folders"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.get("/folders", response_model=list[FolderOut])
async def list_folders(parent_id: str | None = None):
    db = await get_db()
    if parent_id:
        rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id = ? ORDER BY name", (parent_id,)
        )
    else:
        rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id IS NULL ORDER BY name"
        )
    return [dict(r) for r in rows]


@router.post("/folders", response_model=FolderOut, status_code=201)
async def create_folder(body: FolderCreate):
    db = await get_db()
    folder_id = str(uuid.uuid4())
    now = _now()

    # Build disk path relative to storage root
    if body.parent_id:
        parent = await db.execute_fetchall(
            "SELECT disk_path FROM folders WHERE id = ?", (body.parent_id,)
        )
        if not parent:
            raise HTTPException(404, "Parent folder not found")
        rel = f"{parent[0]['disk_path']}/{body.name}"
    else:
        rel = body.name

    disk_path = str(ensure_folder(rel))

    await db.execute(
        "INSERT INTO folders (id, name, parent_id, disk_path, created_at, updated_at) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (folder_id, body.name, body.parent_id, disk_path, now, now),
    )
    await db.commit()
    return FolderOut(
        id=folder_id, name=body.name, parent_id=body.parent_id,
        created_at=now, updated_at=now,
    )


@router.put("/folders/{folder_id}", response_model=FolderOut)
async def rename_folder(folder_id: str, body: FolderRename):
    db = await get_db()
    row = await db.execute_fetchall(
        "SELECT * FROM folders WHERE id = ?", (folder_id,)
    )
    if not row:
        raise HTTPException(404, "Folder not found")

    now = _now()
    await db.execute(
        "UPDATE folders SET name = ?, updated_at = ? WHERE id = ?",
        (body.name, now, folder_id),
    )
    await db.commit()
    folder = dict(row[0])
    folder["name"] = body.name
    folder["updated_at"] = now
    return folder


@router.delete("/folders/{folder_id}")
async def delete_folder(folder_id: str):
    db = await get_db()
    row = await db.execute_fetchall(
        "SELECT disk_path FROM folders WHERE id = ?", (folder_id,)
    )
    if not row:
        raise HTTPException(404, "Folder not found")

    # Detach OCR task references to avoid FK restrictions
    await db.execute(
        "UPDATE ocr_tasks SET result_folder_id = NULL WHERE result_folder_id = ?",
        (folder_id,),
    )
    await db.commit()

    delete_path(row[0]["disk_path"])
    await db.execute("DELETE FROM folders WHERE id = ?", (folder_id,))
    await db.commit()
    return {"detail": "deleted"}
