import json
import time

from fastapi import FastAPI, Request, Response
from psycopg_pool import ConnectionPool

from .config import settings
from .db import ReaderPool
from .metrics import ERROR_COUNT, REQUEST_COUNT, REQUEST_LATENCY, render_metrics
from .routers import categories, products

writer_pool = ConnectionPool(
    settings.writer_conninfo(),
    min_size=settings.writer_pool_min,
    max_size=settings.writer_pool_max,
    open=False,
    kwargs={"autocommit": True},
)
writer_pool.open(wait=False)

reader_pool = ReaderPool(settings.read_hosts_list)

app = FastAPI(title="DB Scale Lab API")
app.include_router(categories.router)
app.include_router(products.router)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    method = request.method
    start = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        # El routing (y por lo tanto scope["route"]) recién queda resuelto
        # dentro de call_next, al bajar hasta el router de Starlette: leerlo
        # antes (como estaba) siempre daba None y caía al path literal, con
        # cardinalidad explosiva por cada ID distinto (/products/100123, etc).
        route = request.scope.get("route")
        endpoint = route.path if route is not None else request.url.path
        ERROR_COUNT.labels(endpoint=endpoint, method=method, status="500").inc()
        raise
    route = request.scope.get("route")
    # Ruta templada (ej. /products/{id}), no el path literal: evita
    # cardinalidad explosiva por cada ID distinto en las métricas.
    endpoint = route.path if route is not None else request.url.path
    duration = time.perf_counter() - start
    REQUEST_LATENCY.labels(endpoint=endpoint, method=method).observe(duration)
    REQUEST_COUNT.labels(endpoint=endpoint, method=method, status=str(response.status_code)).inc()
    if response.status_code >= 400:
        ERROR_COUNT.labels(endpoint=endpoint, method=method, status=str(response.status_code)).inc()
    return response


@app.get("/health")
def health():
    writer_ok = False
    try:
        with writer_pool.connection(timeout=2) as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            writer_ok = True
    except Exception:  # noqa: BLE001
        writer_ok = False

    reader_ok = reader_pool.healthcheck()

    status = "ok" if (writer_ok and reader_ok) else "degraded"
    body = {"status": status, "writer": writer_ok, "reader": reader_ok}
    return Response(
        content=json.dumps(body),
        media_type="application/json",
        status_code=200 if status == "ok" else 503,
    )


@app.get("/metrics")
def metrics():
    payload, content_type = render_metrics()
    return Response(content=payload, media_type=content_type)
