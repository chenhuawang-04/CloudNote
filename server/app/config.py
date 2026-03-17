"""Configuration loaded from config.yaml + environment variables."""

from __future__ import annotations

import os
from pathlib import Path
from functools import lru_cache

import yaml
from pydantic import BaseModel


_CONFIG_PATH = Path(__file__).resolve().parent.parent / "config.yaml"


class ServerConfig(BaseModel):
    host: str = "0.0.0.0"
    port: int = 8000


class StorageConfig(BaseModel):
    root: str = "./storage"
    max_upload_size_mb: int = 50


class DatabaseConfig(BaseModel):
    path: str = "./cloudnote.db"


class AIConfig(BaseModel):
    base_url: str = "https://api.openai.com/v1"
    api_key: str = ""
    model: str = "gpt-4o"


class PDFConfig(BaseModel):
    pandoc_path: str = "pandoc"
    cjk_css: str = "./app/static/cjk.css"


class CropConfig(BaseModel):
    padding_percent: int = 5


class AppConfig(BaseModel):
    server: ServerConfig = ServerConfig()
    storage: StorageConfig = StorageConfig()
    database: DatabaseConfig = DatabaseConfig()
    ai: AIConfig = AIConfig()
    pdf: PDFConfig = PDFConfig()
    crop: CropConfig = CropConfig()


def _load_yaml() -> dict:
    if _CONFIG_PATH.exists():
        with open(_CONFIG_PATH, "r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    return {}


@lru_cache()
def get_config() -> AppConfig:
    raw = _load_yaml()
    cfg = AppConfig(**raw)

    # Override AI API key from environment variable if set
    env_key = os.getenv("CLOUDNOTE_AI_API_KEY")
    if env_key:
        cfg.ai.api_key = env_key

    # Resolve storage root to absolute path (relative to server/ dir)
    server_dir = _CONFIG_PATH.parent
    cfg.storage.root = str((server_dir / cfg.storage.root).resolve())
    cfg.database.path = str((server_dir / cfg.database.path).resolve())
    cfg.pdf.cjk_css = str((server_dir / cfg.pdf.cjk_css).resolve())

    return cfg
