from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
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


def render_metrics() -> tuple[bytes, str]:
    # Modo multiproceso (gunicorn con varios workers): hay que armar un
    # registry nuevo en cada scrape y juntar los archivos de todos los
    # workers con MultiProcessCollector (ver gunicorn_conf.py: child_exit).
    registry = CollectorRegistry()
    multiprocess.MultiProcessCollector(registry)
    return generate_latest(registry), CONTENT_TYPE_LATEST
