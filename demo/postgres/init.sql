-- init.sql: esquema de negocio (DB Scale Lab). Corre primero en
-- docker-entrypoint-initdb.d (orden alfabético: init.sql, roles.sql, seed.sql).
\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS categories (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS products (
    id          BIGSERIAL PRIMARY KEY,
    category_id BIGINT NOT NULL REFERENCES categories(id),
    name        TEXT NOT NULL,
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Sirve al filtro de GET /products (categoría + rango de precio) y, de forma
-- index-only, al conteo agrupado de GET /categories.
CREATE INDEX IF NOT EXISTS idx_products_category_price ON products (category_id, price);
