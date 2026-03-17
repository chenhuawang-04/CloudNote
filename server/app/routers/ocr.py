"""OCR task submission / status / results routes."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks

from ..config import get_config
from ..database import get_db
from ..models import OcrSubmitOut, OcrStatusOut, OcrResultOut, QuestionResult
from ..services.storage import save_upload
from ..utils.helpers import sanitize_filename

router = APIRouter(tags=["ocr"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.post("/ocr/submit", response_model=OcrSubmitOut, status_code=201)
async def submit_ocr(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    cfg = get_config()
    data = await file.read()
    if len(data) > cfg.storage.max_upload_size_mb * 1024 * 1024:
        raise HTTPException(413, "File too large")

    task_id = str(uuid.uuid4())
    safe_name = sanitize_filename(file.filename or "image.jpg")
    now = _now()

    # Save uploaded image to a temp location
    rel = f"_ocr_pending/{task_id}/{safe_name}"
    disk = await save_upload(data, rel)

    db = await get_db()
    await db.execute(
        "INSERT INTO ocr_tasks (id, original_image, status, created_at, updated_at) "
        "VALUES (?, ?, 'pending', ?, ?)",
        (task_id, str(disk), now, now),
    )
    await db.commit()

    # Launch background processing
    from ..services.ocr_pipeline import run_ocr_pipeline
    background_tasks.add_task(run_ocr_pipeline, task_id)

    return OcrSubmitOut(task_id=task_id, status="pending")


@router.get("/ocr/{task_id}/status", response_model=OcrStatusOut)
async def ocr_status(task_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM ocr_tasks WHERE id = ?", (task_id,)
    )
    if not rows:
        raise HTTPException(404, "Task not found")
    t = dict(rows[0])
    return OcrStatusOut(
        task_id=t["id"],
        status=t["status"],
        progress_msg=t.get("progress_msg"),
        error=t.get("error"),
        question_count=t.get("question_count", 0),
        result_folder_id=t.get("result_folder_id"),
    )


@router.get("/ocr/{task_id}/results", response_model=OcrResultOut)
async def ocr_results(task_id: str):
    db = await get_db()
    rows = await db.execute_fetchall(
        "SELECT * FROM ocr_tasks WHERE id = ?", (task_id,)
    )
    if not rows:
        raise HTTPException(404, "Task not found")
    t = dict(rows[0])
    if t["status"] != "done":
        return OcrResultOut(task_id=task_id, status=t["status"])

    folder_id = t.get("result_folder_id")
    # Gather result files from the folder
    file_rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE folder_id = ? ORDER BY name", (folder_id,)
    )
    files_map = {f["name"]: dict(f) for f in file_rows}

    # Find original
    original_file_id = None
    for name, f in files_map.items():
        if name.startswith("original"):
            original_file_id = f["id"]
            break

    # Build question list
    questions: list[QuestionResult] = []
    i = 1
    while True:
        crop_key = f"q{i}_crop.png"
        md_key = f"q{i}.md"
        pdf_key = f"q{i}.pdf"
        if crop_key not in files_map and md_key not in files_map:
            break

        # Read markdown content from disk if available
        md_content = ""
        if md_key in files_map:
            try:
                with open(files_map[md_key]["disk_path"], "r", encoding="utf-8") as mf:
                    md_content = mf.read()
            except Exception:
                pass

        questions.append(QuestionResult(
            index=i,
            markdown=md_content,
            crop_file_id=files_map.get(crop_key, {}).get("id"),
            md_file_id=files_map.get(md_key, {}).get("id"),
            pdf_file_id=files_map.get(pdf_key, {}).get("id"),
        ))
        i += 1

    return OcrResultOut(
        task_id=task_id,
        status="done",
        original_file_id=original_file_id,
        result_folder_id=folder_id,
        questions=questions,
    )
