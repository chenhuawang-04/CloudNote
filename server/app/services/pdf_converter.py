"""Markdown → PDF conversion using pandoc + WeasyPrint."""

from __future__ import annotations

import subprocess
from pathlib import Path

from ..config import get_config


def md_to_pdf(md_path: str, pdf_path: str) -> None:
    """Convert a Markdown file to PDF using pandoc with WeasyPrint backend.

    Falls back to plain pandoc PDF if WeasyPrint is not available.
    """
    cfg = get_config()
    css = cfg.pdf.cjk_css
    pandoc = cfg.pdf.pandoc_path

    # Try WeasyPrint engine first (best CJK support)
    cmd = [
        pandoc, str(md_path),
        "-o", str(pdf_path),
        "--pdf-engine=weasyprint",
        "--standalone",
    ]
    if Path(css).exists():
        cmd.extend(["--css", css])

    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=60)
        return
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    # Fallback: pandoc default PDF engine (pdflatex/xelatex)
    cmd_fallback = [
        pandoc, str(md_path),
        "-o", str(pdf_path),
        "--standalone",
        "-V", "CJKmainfont=SimSun",
        "--pdf-engine=xelatex",
    ]
    try:
        subprocess.run(cmd_fallback, check=True, capture_output=True, timeout=60)
    except Exception as e:
        raise RuntimeError(f"PDF conversion failed: {e}")
