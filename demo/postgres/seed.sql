-- seed.sql: datos semilla (propuesta §2.5/§2.9): 10 categorías y ~500.000
-- productos con generate_series. Corre último (orden alfabético).
\set ON_ERROR_STOP on

INSERT INTO categories (name, description) VALUES
    ('Electrónica',  'Dispositivos y gadgets electrónicos'),
    ('Hogar',        'Artículos para el hogar'),
    ('Indumentaria', 'Ropa y accesorios'),
    ('Deportes',     'Equipamiento deportivo'),
    ('Juguetes',     'Juguetes y juegos'),
    ('Alimentos',    'Productos alimenticios no perecederos'),
    ('Libros',       'Libros y material de lectura'),
    ('Herramientas', 'Herramientas y ferretería'),
    ('Belleza',      'Cosmética y cuidado personal'),
    ('Mascotas',     'Productos para mascotas')
ON CONFLICT (name) DO NOTHING;

-- category_id en 1..10 porque categories se acaba de poblar en una base
-- recién inicializada (BIGSERIAL arranca en 1, sin huecos).
INSERT INTO products (category_id, name, price, stock, created_at, updated_at)
SELECT
    c.cat_id,
    'Producto ' || s,
    -- banda de precio distinta por categoría + ruido, para que el filtro de
    -- GET /products por categoría+precio tenga sentido.
    round((5 + (c.cat_id * 15) + (random() * 300))::numeric, 2),
    (random() * 1000)::int,
    now() - (random() * interval '730 days'),
    now()
FROM generate_series(1, 500000) AS s
CROSS JOIN LATERAL (SELECT 1 + ((s - 1) % 10) AS cat_id) AS c;

ANALYZE categories;
ANALYZE products;
