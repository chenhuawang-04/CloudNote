"""Pydantic request/response models."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


# ── Folders ──────────────────────────────────────────────

class FolderCreate(BaseModel):
    name: str
    parent_id: Optional[str] = None


class FolderRename(BaseModel):
    name: str


class FolderOut(BaseModel):
    id: str
    name: str
    parent_id: Optional[str] = None
    created_at: str
    updated_at: str


# ── Files ────────────────────────────────────────────────

class FileOut(BaseModel):
    id: str
    name: str
    size: int
    mime_type: Optional[str] = None
    folder_id: Optional[str] = None
    created_at: str


# ── OCR ──────────────────────────────────────────────────

class OcrSubmitOut(BaseModel):
    task_id: str
    status: str = "pending"


class OcrStatusOut(BaseModel):
    task_id: str
    status: str
    progress_msg: Optional[str] = None
    error: Optional[str] = None
    question_count: int = 0
    result_folder_id: Optional[str] = None


class QuestionResult(BaseModel):
    index: int
    markdown: str
    crop_file_id: Optional[str] = None
    md_file_id: Optional[str] = None
    pdf_file_id: Optional[str] = None


class OcrResultOut(BaseModel):
    task_id: str
    status: str
    original_file_id: Optional[str] = None
    result_folder_id: Optional[str] = None
    questions: list[QuestionResult] = []


# ── Browse ───────────────────────────────────────────────

class BrowseOut(BaseModel):
    folders: list[FolderOut] = []
    files: list[FileOut] = []
