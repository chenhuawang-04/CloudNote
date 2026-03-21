"""Thumbnail generation utilities with a strict size cap."""

from __future__ import annotations

import io
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

from .pdf_renderer import ensure_rendered

_META_NAME = "meta.json"
_DEFAULT_SIZE = (320, 320)
_MIN_SIZE = 32
_MAX_BYTES = 100 * 1024
_QUALITY_STEPS = (82, 74, 66, 58, 50, 42, 36, 30)


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


def _write_meta(cache_dir: Path, mtime: float, output_name: str) -> None:
    _meta_path(cache_dir).write_text(
        json.dumps({"mtime": mtime, "output_name": output_name}),
        encoding="utf-8",
    )


def _thumbnail_path(cache_dir: Path, output_name: str) -> Path:
    return cache_dir / output_name


def _cached_thumbnail(cache_dir: Path, source_mtime: float) -> Path | None:
    meta = _load_meta(cache_dir)
    if not meta or meta.get("mtime") != source_mtime:
        return None
    output_name = str(meta.get("output_name", "thumb.jpg"))
    path = _thumbnail_path(cache_dir, output_name)
    return path if path.exists() else None


def _clear_cache(cache_dir: Path) -> None:
    if not cache_dir.exists():
        return
    for path in cache_dir.iterdir():
        if path.is_file():
            path.unlink(missing_ok=True)


def _is_pdf(name: str, mime_type: str | None) -> bool:
    if mime_type and mime_type.lower() == "application/pdf":
        return True
    return name.lower().endswith(".pdf")


def _open_source_image(
    source_path: str,
    cache_dir: Path,
    *,
    file_name: str,
    mime_type: str | None,
) -> Image.Image:
    if _is_pdf(file_name, mime_type):
        render_dir = cache_dir / "_pdf"
        ensure_rendered(source_path, render_dir, scale=1.5)
        return Image.open(render_dir / "page_1.png")

    if mime_type and mime_type.startswith("image/"):
        return Image.open(source_path)

    return _build_placeholder(file_name)


def _build_placeholder(file_name: str) -> Image.Image:
    image = Image.new("RGB", _DEFAULT_SIZE, "#EEF2F6")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((20, 20, 300, 300), radius=28, fill="#D7E2EC")

    suffix = Path(file_name).suffix.upper().replace(".", "") or "FILE"
    label = suffix[:6]
    font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), label, font=font)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    draw.text(
        ((320 - width) / 2, (320 - height) / 2),
        label,
        fill="#334155",
        font=font,
    )
    return image


def _normalize_image(image: Image.Image) -> Image.Image:
    normalized = ImageOps.exif_transpose(image)
    if normalized.mode in {"RGBA", "LA"} or (
        normalized.mode == "P" and "transparency" in normalized.info
    ):
        background = Image.new("RGB", normalized.size, "white")
        alpha = normalized.convert("RGBA")
        background.paste(alpha, mask=alpha.getchannel("A"))
        return background
    return normalized.convert("RGB")


def _fit_image(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    result = image.copy()
    result.thumbnail(max_size, Image.Resampling.LANCZOS)
    return result


def _compress_jpeg(image: Image.Image, max_bytes: int) -> bytes:
    current = image
    while True:
        last_payload = b""
        for quality in _QUALITY_STEPS:
            buffer = io.BytesIO()
            current.save(
                buffer,
                format="JPEG",
                quality=quality,
                optimize=True,
                progressive=True,
            )
            data = buffer.getvalue()
            last_payload = data
            if len(data) <= max_bytes:
                return data

        next_width = int(current.width * 0.85)
        next_height = int(current.height * 0.85)
        if next_width < _MIN_SIZE or next_height < _MIN_SIZE:
            return last_payload

        current = _fit_image(current, (next_width, next_height))


def ensure_thumbnail(
    source_path: str,
    cache_dir: Path,
    *,
    file_name: str,
    mime_type: str | None,
    max_bytes: int = _MAX_BYTES,
) -> Path:
    """Create or reuse a thumbnail capped at max_bytes and return its path."""

    cache_dir.mkdir(parents=True, exist_ok=True)
    source_mtime = os.path.getmtime(source_path)
    cached = _cached_thumbnail(cache_dir, source_mtime)
    if cached is not None:
        return cached

    _clear_cache(cache_dir)

    image = _open_source_image(
        source_path,
        cache_dir,
        file_name=file_name,
        mime_type=mime_type,
    )
    try:
        normalized = _normalize_image(image)
        thumbnail = _fit_image(normalized, _DEFAULT_SIZE)
        payload = _compress_jpeg(thumbnail, max_bytes)
    finally:
        image.close()

    output_name = "thumb.jpg"
    output_path = _thumbnail_path(cache_dir, output_name)
    output_path.write_bytes(payload)
    _write_meta(cache_dir, source_mtime, output_name)
    return output_path
