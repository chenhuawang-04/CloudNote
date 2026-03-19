from __future__ import annotations

from aiosqlite import Connection, Row

from .storage import delete_path


def _placeholders(count: int) -> str:
    return ",".join("?" for _ in range(count))


async def fetch_active_folder(db: Connection, folder_id: str) -> Row | None:
    rows = await db.execute_fetchall(
        "SELECT * FROM folders WHERE id = ? AND deleted_at IS NULL",
        (folder_id,),
    )
    return rows[0] if rows else None


async def fetch_deleted_folder(db: Connection, folder_id: str) -> Row | None:
    rows = await db.execute_fetchall(
        "SELECT * FROM folders WHERE id = ? AND deleted_at IS NOT NULL",
        (folder_id,),
    )
    return rows[0] if rows else None


async def fetch_active_file(db: Connection, file_id: str) -> Row | None:
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ? AND deleted_at IS NULL",
        (file_id,),
    )
    return rows[0] if rows else None


async def fetch_deleted_file(db: Connection, file_id: str) -> Row | None:
    rows = await db.execute_fetchall(
        "SELECT * FROM files WHERE id = ? AND deleted_at IS NOT NULL",
        (file_id,),
    )
    return rows[0] if rows else None


async def folder_descendant_ids(db: Connection, folder_id: str) -> list[str]:
    rows = await db.execute_fetchall(
        """
        WITH RECURSIVE descendants(id) AS (
            SELECT id FROM folders WHERE id = ?
            UNION ALL
            SELECT child.id
            FROM folders child
            JOIN descendants parent ON child.parent_id = parent.id
        )
        SELECT id FROM descendants
        """,
        (folder_id,),
    )
    return [row["id"] for row in rows]


async def folder_ancestor_ids(db: Connection, folder_id: str) -> list[str]:
    rows = await db.execute_fetchall(
        """
        WITH RECURSIVE ancestors(id, parent_id) AS (
            SELECT id, parent_id FROM folders WHERE id = ?
            UNION ALL
            SELECT parent.id, parent.parent_id
            FROM folders parent
            JOIN ancestors child ON child.parent_id = parent.id
        )
        SELECT id FROM ancestors
        """,
        (folder_id,),
    )
    return [row["id"] for row in rows]


async def soft_delete_file(db: Connection, file_id: str, deleted_at: str) -> bool:
    file_row = await fetch_active_file(db, file_id)
    if file_row is None:
        return False
    await db.execute(
        "UPDATE files SET deleted_at = ? WHERE id = ?",
        (deleted_at, file_id),
    )
    return True


async def soft_delete_folder_tree(
    db: Connection, folder_id: str, deleted_at: str, updated_at: str
) -> bool:
    folder_row = await fetch_active_folder(db, folder_id)
    if folder_row is None:
        return False

    folder_ids = await folder_descendant_ids(db, folder_id)
    placeholders = _placeholders(len(folder_ids))

    await db.execute(
        f"UPDATE folders SET deleted_at = ?, updated_at = ? WHERE id IN ({placeholders})",
        (deleted_at, updated_at, *folder_ids),
    )
    await db.execute(
        f"UPDATE files SET deleted_at = ? WHERE folder_id IN ({placeholders})",
        (deleted_at, *folder_ids),
    )
    return True


async def restore_file(db: Connection, file_id: str) -> bool:
    file_row = await fetch_deleted_file(db, file_id)
    if file_row is None:
        return False

    if file_row["folder_id"]:
        ancestor_ids = await folder_ancestor_ids(db, file_row["folder_id"])
        if ancestor_ids:
            placeholders = _placeholders(len(ancestor_ids))
            await db.execute(
                f"UPDATE folders SET deleted_at = NULL WHERE id IN ({placeholders})",
                ancestor_ids,
            )

    await db.execute(
        "UPDATE files SET deleted_at = NULL WHERE id = ?",
        (file_id,),
    )
    return True


async def restore_folder_tree(db: Connection, folder_id: str) -> bool:
    folder_row = await fetch_deleted_folder(db, folder_id)
    if folder_row is None:
        return False

    ancestor_ids = await folder_ancestor_ids(db, folder_id)
    subtree_ids = await folder_descendant_ids(db, folder_id)
    restore_folder_ids = list(dict.fromkeys([*ancestor_ids, *subtree_ids]))

    if restore_folder_ids:
        placeholders = _placeholders(len(restore_folder_ids))
        await db.execute(
            f"UPDATE folders SET deleted_at = NULL WHERE id IN ({placeholders})",
            restore_folder_ids,
        )

    if subtree_ids:
        placeholders = _placeholders(len(subtree_ids))
        await db.execute(
            f"UPDATE files SET deleted_at = NULL WHERE folder_id IN ({placeholders})",
            subtree_ids,
        )

    return True


async def purge_file(db: Connection, file_id: str) -> bool:
    file_row = await fetch_deleted_file(db, file_id)
    if file_row is None:
        return False

    delete_path(file_row["disk_path"])
    await db.execute("DELETE FROM files WHERE id = ?", (file_id,))
    return True


async def purge_folder_tree(db: Connection, folder_id: str) -> bool:
    folder_row = await fetch_deleted_folder(db, folder_id)
    if folder_row is None:
        return False

    folder_ids = await folder_descendant_ids(db, folder_id)
    if folder_ids:
        placeholders = _placeholders(len(folder_ids))
        await db.execute(
            f"UPDATE ocr_tasks SET result_folder_id = NULL WHERE result_folder_id IN ({placeholders})",
            folder_ids,
        )

    delete_path(folder_row["disk_path"])
    await db.execute("DELETE FROM folders WHERE id = ?", (folder_id,))
    return True


async def list_top_level_deleted(db: Connection) -> tuple[list[dict], list[dict]]:
    folder_rows = await db.execute_fetchall(
        """
        SELECT child.*
        FROM folders child
        LEFT JOIN folders parent ON child.parent_id = parent.id
        WHERE child.deleted_at IS NOT NULL
          AND (parent.id IS NULL OR parent.deleted_at IS NULL)
        ORDER BY child.deleted_at DESC, child.name
        """
    )
    file_rows = await db.execute_fetchall(
        """
        SELECT file.*
        FROM files file
        LEFT JOIN folders folder ON file.folder_id = folder.id
        WHERE file.deleted_at IS NOT NULL
          AND (folder.id IS NULL OR folder.deleted_at IS NULL)
        ORDER BY file.deleted_at DESC, file.name
        """
    )
    return [dict(row) for row in folder_rows], [dict(row) for row in file_rows]


async def clear_trash(db: Connection) -> tuple[int, int]:
    folders, files = await list_top_level_deleted(db)

    for folder in folders:
        await purge_folder_tree(db, folder["id"])
    for file in files:
        await purge_file(db, file["id"])

    return len(folders), len(files)


async def active_name_search(
    db: Connection, query: str, folder_id: str | None = None
) -> tuple[list[dict], list[dict]]:
    if folder_id:
        folder_rows = await db.execute_fetchall(
            """
            WITH RECURSIVE scope(id) AS (
                SELECT id FROM folders WHERE id = ? AND deleted_at IS NULL
                UNION ALL
                SELECT child.id
                FROM folders child
                JOIN scope parent ON child.parent_id = parent.id
                WHERE child.deleted_at IS NULL
            )
            SELECT *
            FROM folders
            WHERE deleted_at IS NULL
              AND id != ?
              AND id IN (SELECT id FROM scope)
              AND LOWER(name) LIKE ?
            ORDER BY name
            """,
            (folder_id, folder_id, query),
        )
        file_rows = await db.execute_fetchall(
            """
            WITH RECURSIVE scope(id) AS (
                SELECT id FROM folders WHERE id = ? AND deleted_at IS NULL
                UNION ALL
                SELECT child.id
                FROM folders child
                JOIN scope parent ON child.parent_id = parent.id
                WHERE child.deleted_at IS NULL
            )
            SELECT *
            FROM files
            WHERE deleted_at IS NULL
              AND folder_id IN (SELECT id FROM scope)
              AND LOWER(name) LIKE ?
            ORDER BY name
            """,
            (folder_id, query),
        )
    else:
        folder_rows = await db.execute_fetchall(
            """
            SELECT *
            FROM folders
            WHERE deleted_at IS NULL
              AND LOWER(name) LIKE ?
            ORDER BY name
            """,
            (query,),
        )
        file_rows = await db.execute_fetchall(
            """
            SELECT *
            FROM files
            WHERE deleted_at IS NULL
              AND LOWER(name) LIKE ?
            ORDER BY name
            """,
            (query,),
        )

    return [dict(row) for row in folder_rows], [dict(row) for row in file_rows]
