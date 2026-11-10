import psycopg
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from ..config import settings
from ..db import rows_to_dicts
from ..models import ProductOut, ProductUpdate, ProductWithCategory

router = APIRouter(prefix="/products", tags=["products"])


class ProductCreate(BaseModel):
    category_id: int
    name: str
    price: float
    stock: int = 0


@router.post("", response_model=ProductOut, status_code=201)
def create_product(body: ProductCreate):
    from ..main import writer_pool

    try:
        with writer_pool.connection() as conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO products (category_id, name, price, stock) "
                "VALUES (%s, %s, %s, %s) "
                "RETURNING id, category_id, name, price, stock, created_at, updated_at",
                (body.category_id, body.name, body.price, body.stock),
            )
            row = cur.fetchone()
            columns = [d.name for d in cur.description]
    except psycopg.errors.ForeignKeyViolation:
        raise HTTPException(status_code=404, detail="categoría inexistente")
    return rows_to_dicts(columns, [row])[0]


@router.get("", response_model=list[ProductOut])
def list_products(
    category_id: int | None = None,
    min_price: float | None = None,
    max_price: float | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    from ..main import reader_pool

    clauses, params = [], []
    if category_id is not None:
        clauses.append("category_id = %s")
        params.append(category_id)
    if min_price is not None:
        clauses.append("price >= %s")
        params.append(min_price)
    if max_price is not None:
        clauses.append("price <= %s")
        params.append(max_price)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    params.extend([limit, offset])

    columns, rows = reader_pool.run(
        f"SELECT id, category_id, name, price, stock, created_at, updated_at "
        f"FROM products {where} ORDER BY id LIMIT %s OFFSET %s",
        tuple(params),
    )
    return rows_to_dicts(columns, rows)


@router.get("/{product_id}", response_model=ProductWithCategory)
def get_product(product_id: int):
    from ..main import reader_pool, writer_pool

    query = (
        "SELECT p.id, p.category_id, p.name, p.price, p.stock, "
        "p.created_at, p.updated_at, c.name AS category_name "
        "FROM products p JOIN categories c ON c.id = p.category_id "
        "WHERE p.id = %s"
    )
    columns, rows = reader_pool.run(query, (product_id,))
    if not rows and settings.read_fallback_to_primary:
        # Lag de replicación (propuesta §2.6/§3.3): la réplica puede no tener
        # todavía la fila. Con base única esto es un no-op (reader == primario).
        with writer_pool.connection() as conn, conn.cursor() as cur:
            cur.execute(query, (product_id,))
            row = cur.fetchone()
            columns = [d.name for d in cur.description] if cur.description else []
            rows = [row] if row else []
    if not rows:
        raise HTTPException(status_code=404, detail="producto no encontrado")
    return rows_to_dicts(columns, rows)[0]


@router.put("/{product_id}", response_model=ProductOut)
def update_product(product_id: int, body: ProductUpdate):
    from ..main import writer_pool

    with writer_pool.connection() as conn, conn.cursor() as cur:
        cur.execute(
            "UPDATE products SET price = %s, stock = %s, updated_at = now() "
            "WHERE id = %s "
            "RETURNING id, category_id, name, price, stock, created_at, updated_at",
            (body.price, body.stock, product_id),
        )
        row = cur.fetchone()
        columns = [d.name for d in cur.description] if cur.description else []
    if row is None:
        raise HTTPException(status_code=404, detail="producto no encontrado")
    return rows_to_dicts(columns, [row])[0]
