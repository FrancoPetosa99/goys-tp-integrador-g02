import os
import shutil

bind = "0.0.0.0:8000"
workers = int(os.getenv("GUNICORN_WORKERS", "4"))
worker_class = "uvicorn.workers.UvicornWorker"
timeout = 30
graceful_timeout = 30

_MULTIPROC_DIR = os.environ["PROMETHEUS_MULTIPROC_DIR"]


def on_starting(server):
    # Limpia métricas de una corrida anterior (restart del contenedor): el
    # modo multiproceso de prometheus_client guarda un archivo por worker en
    # este directorio y los suma en /metrics.
    shutil.rmtree(_MULTIPROC_DIR, ignore_errors=True)
    os.makedirs(_MULTIPROC_DIR, exist_ok=True)


def child_exit(server, worker):
    from prometheus_client import multiprocess

    multiprocess.mark_process_dead(worker.pid)
