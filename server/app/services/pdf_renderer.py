"""PDF rendering utilities for image previews."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pypdfium2 as pdfium


_META_NAME = "meta.json"


def _meta_path(cache_dir: Path) -> Path:
    return cache_dir / _META_NAME


def _load_meta(cache_dir: Path) -> dict | None:
    path = _meta_path(cache_dir)
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _write_meta(cache_dir: Path, pages: int, mtime: float) -> None:
    path = _meta_path(cache_dir)
    path.write_text(
        json.dumps({"pages": pages, "mtime": mtime}),
        encoding="utf-8",
    )


def _pages_exist(cache_dir: Path, pages: int) -> bool:
    for i in range(1, pages + 1):
        if not (cache_dir / f"page_{i}.png").exists():
            return False
    return True


def _clear_cache(cache_dir: Path) -> None:
    if not cache_dir.exists():
        return
    for p in cache_dir.glob("page_*.png"):
        p.unlink(missing_ok=True)


def ensure_rendered(pdf_path: str, cache_dir: Path, scale: float = 2.0) -> int:
    """Render all pages of a PDF into cache_dir and return page count."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    pdf_mtime = os.path.getmtime(pdf_path)
    meta = _load_meta(cache_dir)
    if meta and meta.get("mtime") == pdf_mtime:
        pages = int(meta.get("pages", 0))
        if pages > 0 and _pages_exist(cache_dir, pages):
            return pages

    _clear_cache(cache_dir)

    doc = pdfium.PdfDocument(pdf_path)
    try:
        pages = len(doc)
        for index in range(pages):
            page = doc[index]
            bitmap = page.render(scale=scale)
            image = bitmap.to_pil()
            image.save(cache_dir / f"page_{index + 1}.png")
            page.close()
        _write_meta(cache_dir, pages, pdf_mtime)
        return pages
    finally:
        doc.close()
