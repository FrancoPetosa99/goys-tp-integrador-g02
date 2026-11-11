from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    multiprocess,
    generate_latest,
)

REQUEST_COUNT = Counter(
    "api_requests_total", "Requests por endpoint", ["endpoint", "method", "status"]
)
REQUEST_LATENCY = Histogram(
    "api_request_latency_seconds", "Latencia por endpoint", ["endpoint", "method"]
)
ERROR_COUNT = Counter(
    "api_errors_total", "Errores por endpoint", ["endpoint", "method", "status"]
)
READS_BY_NODE = Counter(
    "api_reads_by_node_total", "Lecturas servidas, por nodo de base de datos", ["host"]
)
# multiprocess_mode="min": cada worker de gunicorn tiene su propio ReaderPool
# (y su propio estado de salud por host). Si al menos un worker ve el host
# caído, se reporta caído: para una alerta conviene el escenario pesimista,
# no promediar entre workers.
READER_HOST_HEALTHY = Gauge(
    "api_reader_host_healthy",
    "Salud de cada host de lectura según la app (1=sano, 0=caído)",
    ["host"],
    multiprocess_mode="min",
)


def render_metrics() -> tuple[bytes, str]:
    # Modo multiproceso (gunicorn con varios workers): hay que armar un
    # registry nuevo en cada scrape y juntar los archivos de todos los
    # workers con MultiProcessCollector (ver gunicorn_conf.py: child_exit).
    registry = CollectorRegistry()
    multiprocess.MultiProcessCollector(registry)
    return generate_latest(registry), CONTENT_TYPE_LATEST
