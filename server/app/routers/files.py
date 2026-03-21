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
from ..models import FileOut, BrowseOut
from ..services.pdf_renderer import ensure_rendered
from ..services.storage import save_upload
from ..services.thumbnailer import ensure_thumbnail
from ..services.trash import (
    active_name_search,
    clear_trash,
    fetch_active_file,
    fetch_active_folder,
    list_top_level_deleted,
    purge_file,
    purge_folder_tree,
    restore_file,
    restore_folder_tree,
    soft_delete_file,
)
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
            "SELECT * FROM files WHERE folder_id = ? AND deleted_at IS NULL ORDER BY name",
            (folder_id,),
        )
    else:
        rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id IS NULL AND deleted_at IS NULL ORDER BY name"
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
        folder_row = await fetch_active_folder(db, folder_id)
        if folder_row is None:
            raise HTTPException(404, "Folder not found")
        rel = str(Path(folder_row["disk_path"]) / safe_name)
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
    row = await fetch_active_file(db, file_id)
    if row is None:
        raise HTTPException(404, "File not found")
    f = dict(row)
    p = Path(f["disk_path"])
    if not p.exists():
        raise HTTPException(404, "File missing from disk")
    return FileResponse(
        str(p), filename=f["name"], media_type=f.get("mime_type"),
    )


@router.get("/files/{file_id}/thumbnail")
async def file_thumbnail(file_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ?",
        (file_id,),
    )
    if not rows:
        raise HTTPException(404, "File not found")

    file_row = dict(rows[0])
    source_path = Path(file_row["disk_path"])
    if not source_path.exists():
        raise HTTPException(404, "File missing from disk")

    cfg = get_config()
    cache_dir = Path(cfg.storage.root) / "_thumbs" / file_id
    thumbnail_path = await run_in_threadpool(
        ensure_thumbnail,
        str(source_path),
        cache_dir,
        file_name=file_row["name"],
        mime_type=file_row.get("mime_type"),
    )
    return FileResponse(str(thumbnail_path), media_type="image/jpeg")


@router.get("/files/{file_id}/render/pages")
async def render_pdf_pages(file_id: str):
    db = await get_db()
    row = await fetch_active_file(db, file_id)
    if row is None:
        raise HTTPException(404, "File not found")
    f = dict(row)
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
    row = await fetch_active_file(db, file_id)
    if row is None:
        raise HTTPException(404, "File not found")
    f = dict(row)
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
    row = await fetch_active_file(db, file_id)
    if row is None:
        raise HTTPException(404, "File not found")
    return dict(row)


@router.delete("/files/{file_id}")
async def delete_file(file_id: str):
    db = await get_db()
    deleted = await soft_delete_file(db, file_id, _now())
    if not deleted:
        raise HTTPException(404, "File not found")
    await db.commit()
    return {"detail": "moved_to_trash"}


@router.get("/browse", response_model=BrowseOut)
async def browse(folder_id: str | None = None):
    db = await get_db()
    if folder_id:
        folder_rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id = ? AND deleted_at IS NULL ORDER BY name",
            (folder_id,),
        )
        file_rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id = ? AND deleted_at IS NULL ORDER BY name",
            (folder_id,),
        )
    else:
        folder_rows = await db.execute_fetchall(
            "SELECT * FROM folders WHERE parent_id IS NULL AND deleted_at IS NULL ORDER BY name"
        )
        file_rows = await db.execute_fetchall(
            "SELECT * FROM files WHERE folder_id IS NULL AND deleted_at IS NULL ORDER BY name"
        )
    return BrowseOut(
        folders=[dict(r) for r in folder_rows],
        files=[dict(r) for r in file_rows],
    )


@router.get("/search", response_model=BrowseOut)
async def search(q: str, folder_id: str | None = None):
    query = q.strip().lower()
    if not query:
        return BrowseOut()

    db = await get_db()
    folders, files = await active_name_search(
        db,
        f"%{query}%",
        folder_id=folder_id,
    )
    return BrowseOut(folders=folders, files=files)


@router.get("/trash", response_model=BrowseOut)
async def browse_trash():
    db = await get_db()
    folders, files = await list_top_level_deleted(db)
    return BrowseOut(folders=folders, files=files)


@router.post("/trash/files/{file_id}/restore")
async def restore_trashed_file(file_id: str):
    db = await get_db()
    restored = await restore_file(db, file_id)
    if not restored:
        raise HTTPException(404, "File not found")
    await db.commit()
    return {"detail": "restored"}


@router.post("/trash/folders/{folder_id}/restore")
async def restore_trashed_folder(folder_id: str):
    db = await get_db()
    restored = await restore_folder_tree(db, folder_id)
    if not restored:
        raise HTTPException(404, "Folder not found")
    await db.commit()
    return {"detail": "restored"}


@router.delete("/trash/files/{file_id}")
async def purge_trashed_file(file_id: str):
    db = await get_db()
    deleted = await purge_file(db, file_id)
    if not deleted:
        raise HTTPException(404, "File not found")
    await db.commit()
    return {"detail": "deleted_forever"}


@router.delete("/trash/folders/{folder_id}")
async def purge_trashed_folder(folder_id: str):
    db = await get_db()
    deleted = await purge_folder_tree(db, folder_id)
    if not deleted:
        raise HTTPException(404, "Folder not found")
    await db.commit()
    return {"detail": "deleted_forever"}


@router.delete("/trash")
async def empty_trash():
    db = await get_db()
    deleted_folders, deleted_files = await clear_trash(db)
    await db.commit()
    return {
        "detail": "trash_emptied",
        "folders": deleted_folders,
        "files": deleted_files,
    }
