"""SQLite database initialization and connection management."""

from __future__ import annotations

import aiosqlite

from .config import get_config

_db: aiosqlite.Connection | None = None

_SCHEMA = """
CREATE TABLE IF NOT EXISTS folders (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT,
    disk_path TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES folders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    size INTEGER NOT NULL,
    mime_type TEXT,
    folder_id TEXT,
    disk_path TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS ocr_tasks (
    id TEXT PRIMARY KEY,
    original_image TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    progress_msg TEXT,
    error TEXT,
    result_folder_id TEXT,
    question_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (result_folder_id) REFERENCES folders(id)
);
"""


async def init_db() -> None:
    global _db
    cfg = get_config()
    _db = await aiosqlite.connect(cfg.database.path)
    _db.row_factory = aiosqlite.Row
    await _db.execute("PRAGMA journal_mode=WAL")
    await _db.execute("PRAGMA foreign_keys=ON")
    await _db.executescript(_SCHEMA)
    await _db.commit()


async def get_db() -> aiosqlite.Connection:
    if _db is None:
        await init_db()
    return _db
