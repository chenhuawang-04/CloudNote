"""Image cropping by vertical percentage."""

from __future__ import annotations

from PIL import Image

from ..config import get_config


def crop_question(
    image_path: str,
    start_pct: float,
    end_pct: float,
    output_path: str,
    padding_pct: float | None = None,
) -> None:
    """Crop an image vertically by percentage range with padding."""
    if padding_pct is None:
        padding_pct = get_config().crop.padding_percent

    img = Image.open(image_path)
    width, height = img.size

    y_start = max(0, int(height * (start_pct - padding_pct) / 100))
    y_end = min(height, int(height * (end_pct + padding_pct) / 100))

    cropped = img.crop((0, y_start, width, y_end))
    cropped.save(output_path)
