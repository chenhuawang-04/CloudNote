"""File upload / download / list / delete routes."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse

from ..config import get_config
from ..database import get_db
from ..models import FileOut, BrowseOut, FolderOut
from ..services.pdf_renderer import ensure_rendered
from ..services.storage import save_upload, delete_path
from ..utils.helpers import sanitize_filename, guess_mime

router = APIRouter(tags=["files"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _is_pdf(name: str, mime: str | None) -> bool:
    if mime and mime.lower() == "application/pdf":
        return True
    return name.lower().endswith(".pdf")


@router.get("/files", response_model=list[FileOut])
async def list_files(folder_id: str | None = None):
    db = await get_db()
    if folder_id:
        rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id = ? ORDER BY name", (folder_id,)
        )
    else:
        rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id IS NULL ORDER BY name"
        )
    return [dict(r) for r in rows]


@router.post("/files/upload", response_model=FileOut, status_code=201)
async def upload_file(
    file: UploadFile = File(...),
    folder_id: str | None = Form(None),
):
    cfg = get_config()
    data = await file.read()
    if len(data) > cfg.storage.max_upload_size_mb * 1024 * 1024:
        raise HTTPException(413, "File too large")

    db = await get_db()
    file_id = str(uuid.uuid4())
    safe_name = sanitize_filename(file.filename or "upload")
    mime = guess_mime(safe_name)
    now = _now()

    # Determine disk path
    if folder_id:
        rows = await db.execute_fetchall(
            "SELECT disk_path FROM folders WHERE id = ?", (folder_id,)
        )
        if not rows:
            raise HTTPException(404, "Folder not found")
        rel = Path(rows[0]["disk_path"]).name + "/" + safe_name
    else:
        rel = safe_name

    disk = await save_upload(data, rel)

    await db.execute(
        "INSERT INTO files (id, name, size, mime_type, folder_id, disk_path, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (file_id, safe_name, len(data), mime, folder_id, str(disk), now),
    )
    await db.commit()
    return FileOut(
        id=file_id, name=safe_name, size=len(data),
        mime_type=mime, folder_id=folder_id, created_at=now,
    )


@router.get("/files/{file_id}/download")
async def download_file(file_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ?", (file_id,)
    )
    if not rows:
        raise HTTPException(404, "File not found")
    f = dict(rows[0])
    p = Path(f["disk_path"])
    if not p.exists():
        raise HTTPException(404, "File missing from disk")
    return FileResponse(
        str(p), filename=f["name"], media_type=f.get("mime_type"),
    )


@router.get("/files/{file_id}/render/pages")
async def render_pdf_pages(file_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ?", (file_id,),
    )
    if not rows:
        raise HTTPException(404, "File not found")
    f = dict(rows[0])
    if not _is_pdf(f["name"], f.get("mime_type")):
        raise HTTPException(400, "Not a PDF file")
    p = Path(f["disk_path"])
    if not p.exists():
        raise HTTPException(404, "File missing from disk")

    cfg = get_config()
    render_dir = Path(cfg.storage.root) / "_renders" / file_id
    pages = await run_in_threadpool(ensure_rendered, str(p), render_dir)
    return {"pages": pages}


@router.get("/files/{file_id}/render/page/{page}")
async def render_pdf_page(file_id: str, page: int):
    if page < 1:
        raise HTTPException(400, "Invalid page")
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ?", (file_id,),
    )
    if not rows:
        raise HTTPException(404, "File not found")
    f = dict(rows[0])
    if not _is_pdf(f["name"], f.get("mime_type")):
        raise HTTPException(400, "Not a PDF file")
    p = Path(f["disk_path"])
    if not p.exists():
        raise HTTPException(404, "File missing from disk")

    cfg = get_config()
    render_dir = Path(cfg.storage.root) / "_renders" / file_id
    pages = await run_in_threadpool(ensure_rendered, str(p), render_dir)
    if page > pages:
        raise HTTPException(404, "Page out of range")
    img = render_dir / f"page_{page}.png"
    if not img.exists():
        raise HTTPException(404, "Rendered page missing")
    return FileResponse(str(img), media_type="image/png")


@router.get("/files/{file_id}/info", response_model=FileOut)
async def file_info(file_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ?", (file_id,)
    )
    if not rows:
        raise HTTPException(404, "File not found")
    return dict(rows[0])


@router.delete("/files/{file_id}")
async def delete_file(file_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT disk_path FROM files WHERE id = ?", (file_id,)
    )
    if not rows:
        raise HTTPException(404, "File not found")
    delete_path(rows[0]["disk_path"])
    await db.execute("DELETE FROM files WHERE id = ?", (file_id,))
    await db.commit()
    return {"detail": "deleted"}


@router.get("/browse", response_model=BrowseOut)
async def browse(folder_id: str | None = None):
    db = await get_db()
    if folder_id:
        folder_rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id = ? ORDER BY name", (folder_id,)
        )
        file_rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id = ? ORDER BY name", (folder_id,)
        )
    else:
        folder_rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id IS NULL ORDER BY name"
        )
        file_rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id IS NULL ORDER BY name"
        )
    return BrowseOut(
        folders=[dict(r) for r in folder_rows],
        files=[dict(r) for r in file_rows],
    )
