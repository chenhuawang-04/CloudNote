"""OCR full pipeline — orchestrates AI call, image cropping, MD save, PDF conversion."""

from __future__ import annotations

import uuid
import shutil
from datetime import datetime, timezone
from pathlib import Path

from ..config import get_config
from ..database import get_db
from ..services.ai_client import call_vision
from ..services.image_cropper import crop_question
from ..services.pdf_converter import md_to_pdf
from ..services.storage import ensure_folder
from ..utils.helpers import guess_mime


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _update_task(task_id: str, **kwargs) -> None:
    db = await get_db()
    sets = ", ".join(f"{k} = ?" for k in kwargs)
    vals = list(kwargs.values())
    vals.append(_now())
    vals.append(task_id)
    await db.execute(
        f"UPDATE ocr_tasks SET {sets}, updated_at = ? WHERE id = ?", vals
    )
    await db.commit()


async def run_ocr_pipeline(task_id: str) -> None:
    """Background task: run the full OCR pipeline for a given task."""
    try:
        db = await get_db()
        rows = await db.execute_fetchall(
            "SELECT * FROM ocr_tasks WHERE id = ?", (task_id,)
        )
        if not rows:
            return
        task = dict(rows[0])
        image_path = task["original_image"]

        # ── Step 1: Call AI ──
        await _update_task(task_id, status="processing", progress_msg="正在调用AI识别")
        questions = await call_vision(image_path)

        if not questions:
            await _update_task(task_id, status="done", question_count=0, progress_msg="未识别到题目")
            return

        # ── Step 2: Create result folder ──
        await _update_task(task_id, progress_msg="正在创建结果文件夹")
        original_name = Path(image_path).stem
        folder_name = original_name or f"ocr_{task_id[:8]}"
        folder_id = str(uuid.uuid4())
        disk_path = str(ensure_folder(folder_name))
        now = _now()

        await db.execute(
            "INSERT INTO folders (id, name, parent_id, disk_path, created_at, updated_at) "
            "VALUES (?, ?, NULL, ?, ?, ?)",
            (folder_id, folder_name, disk_path, now, now),
        )
        await db.commit()

        # ── Step 3: Copy original image ──
        original_ext = Path(image_path).suffix
        original_dest = Path(disk_path) / f"original{original_ext}"
        shutil.copy2(image_path, str(original_dest))

        orig_file_id = str(uuid.uuid4())
        orig_size = original_dest.stat().st_size
        await db.execute(
            "INSERT INTO files (id, name, size, mime_type, folder_id, disk_path, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (orig_file_id, f"original{original_ext}", orig_size,
             guess_mime(str(original_dest)), folder_id, str(original_dest), now),
        )
        await db.commit()

        # ── Step 4: Process each question ──
        for i, q in enumerate(questions, 1):
            await _update_task(
                task_id, progress_msg=f"正在处理第 {i}/{len(questions)} 题"
            )

            # 4a. Crop image
            crop_path = Path(disk_path) / f"q{i}_crop.png"
            crop_question(image_path, q["start_percent"], q["end_percent"], str(crop_path))

            crop_id = str(uuid.uuid4())
            crop_size = crop_path.stat().st_size
            await db.execute(
                "INSERT INTO files (id, name, size, mime_type, folder_id, disk_path, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (crop_id, f"q{i}_crop.png", crop_size, "image/png", folder_id, str(crop_path), now),
            )

            # 4b. Save Markdown
            md_path = Path(disk_path) / f"q{i}.md"
            md_path.write_text(q["markdown"], encoding="utf-8")

            md_id = str(uuid.uuid4())
            md_size = md_path.stat().st_size
            await db.execute(
                "INSERT INTO files (id, name, size, mime_type, folder_id, disk_path, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (md_id, f"q{i}.md", md_size, "text/markdown", folder_id, str(md_path), now),
            )

            # 4c. Convert to PDF
            pdf_path = Path(disk_path) / f"q{i}.pdf"
            try:
                md_to_pdf(str(md_path), str(pdf_path))
                if pdf_path.exists():
                    pdf_id = str(uuid.uuid4())
                    pdf_size = pdf_path.stat().st_size
                    await db.execute(
                        "INSERT INTO files (id, name, size, mime_type, folder_id, disk_path, created_at) "
                        "VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (pdf_id, f"q{i}.pdf", pdf_size, "application/pdf", folder_id, str(pdf_path), now),
                    )
            except Exception:
                # PDF conversion is optional — don't fail the whole pipeline
                pass

            await db.commit()

        # ── Step 5: Mark done ──
        await _update_task(
            task_id,
            status="done",
            question_count=len(questions),
            result_folder_id=folder_id,
            progress_msg="完成",
        )

    except Exception as e:
        await _update_task(task_id, status="failed", error=str(e))
