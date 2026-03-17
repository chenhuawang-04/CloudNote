"""FastAPI application entry point."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_config
from .database import init_db
from .routers import files, folders, ocr


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database and storage on startup."""
    cfg = get_config()
    # Ensure storage directory exists
    import os
    os.makedirs(cfg.storage.root, exist_ok=True)
    # Ensure database directory exists
    os.makedirs(os.path.dirname(cfg.database.path), exist_ok=True)
    # Initialize database
    await init_db()
    yield


app = FastAPI(
    title="CloudNote",
    description="跨平台云存储 & 图片OCR工具",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(folders.router, prefix="/api/v1")
app.include_router(files.router, prefix="/api/v1")
app.include_router(ocr.router, prefix="/api/v1")


@app.get("/api/v1/health")
async def health():
    return {"status": "ok"}
