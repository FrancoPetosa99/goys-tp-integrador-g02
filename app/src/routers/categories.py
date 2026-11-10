import psycopg
from fastapi import APIRouter, HTTPException

from ..db import rows_to_dicts
from ..models import CategoryIn, CategoryOut, CategoryWithCount

router = APIRouter(prefix="/categories", tags=["categories"])


@router.post("", response_model=CategoryOut, status_code=201)
def create_category(body: CategoryIn):
    from ..main import writer_pool

    try:
        with writer_pool.connection() as conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO categories (name, description) VALUES (%s, %s) "
                "RETURNING id, name, description, created_at",
                (body.name, body.description),
            )
            row = cur.fetchone()
            columns = [d.name for d in cur.description]
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="ya existe una categoría con ese nombre")
    return rows_to_dicts(columns, [row])[0]


@router.get("", response_model=list[CategoryWithCount])
def list_categories():
    from ..main import reader_pool

    columns, rows = reader_pool.run(
        "SELECT c.id, c.name, c.description, c.created_at, "
        "COUNT(p.id) AS product_count "
        "FROM categories c LEFT JOIN products p ON p.category_id = c.id "
        "GROUP BY c.id ORDER BY c.id"
    )
    return rows_to_dicts(columns, rows)


@router.get("/{category_id}", response_model=CategoryOut)
def get_category(category_id: int):
    from ..main import reader_pool

    columns, rows = reader_pool.run(
        "SELECT id, name, description, created_at FROM categories WHERE id = %s",
        (category_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="categoría no encontrada")
    return rows_to_dicts(columns, rows)[0]


@router.put("/{category_id}", response_model=CategoryOut)
def update_category(category_id: int, body: CategoryIn):
    from ..main import writer_pool

    try:
        with writer_pool.connection() as conn, conn.cursor() as cur:
            cur.execute(
                "UPDATE categories SET name = %s, description = %s WHERE id = %s "
                "RETURNING id, name, description, created_at",
                (body.name, body.description, category_id),
            )
            row = cur.fetchone()
            columns = [d.name for d in cur.description] if cur.description else []
    except psycopg.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="ya existe una categoría con ese nombre")
    if row is None:
        raise HTTPException(status_code=404, detail="categoría no encontrada")
    return rows_to_dicts(columns, [row])[0]
