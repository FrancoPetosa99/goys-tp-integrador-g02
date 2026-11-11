import logging
import threading
import time

from psycopg_pool import ConnectionPool

from .config import settings
from .metrics import READS_BY_NODE

logger = logging.getLogger("dbscale.db")

# Ventana de gracia para los nodos que recién arrancan: el sidecar de ruteo
# (D5) aplica la ruta por defecto DESPUÉS de que el nodo principal arranca,
# así que las primeras conexiones pueden fallar durante ese corto lapso.
# psycopg_pool reintenta solo en segundo plano; acá solo evitamos marcar un
# host como "caído" por un único fallo transitorio.
_FAIL_THRESHOLD = 3


class _ReadHost:
    def __init__(self, host: str):
        self.host = host
        self.pool = ConnectionPool(
            settings.reader_conninfo(host),
            min_size=settings.reader_pool_min,
            max_size=settings.reader_pool_max,
            open=False,
            kwargs={"autocommit": True},
        )
        self.pool.open(wait=False)
        self._consecutive_failures = 0
        self._lock = threading.Lock()

    @property
    def healthy(self) -> bool:
        return self._consecutive_failures < _FAIL_THRESHOLD

    def mark_ok(self):
        with self._lock:
            self._consecutive_failures = 0

    def mark_failed(self):
        with self._lock:
            self._consecutive_failures += 1


class ReaderPool:
    """Round-robin entre los hosts de lectura disponibles (D1/§2.6).

    Con base única, `settings.read_hosts_list` tiene un solo host (el
    primario): el round-robin degenera a "siempre ese host", que es
    exactamente el comportamiento esperado hasta que existan réplicas
    (fase 3).
    """

    def __init__(self, hosts: list[str]):
        self._hosts = [_ReadHost(h) for h in hosts]
        self._cycle_lock = threading.Lock()
        self._next_start = 0

    def _next_candidates(self):
        n = len(self._hosts)
        # Avanza el punto de partida en 1 por llamada (no en `n`): con
        # itertools.cycle y un consumo de `n` elementos por llamada, la fase
        # vuelve siempre al mismo punto de partida (consumís un período
        # completo cada vez) y el "round-robin" degenera en "siempre el
        # primer host sano". Este índice sí rota.
        with self._cycle_lock:
            start = self._next_start
            self._next_start = (self._next_start + 1) % n
        return [self._hosts[(start + i) % n] for i in range(n)]

    def run(self, query: str, params: tuple = ()):
        """Ejecuta una lectura en el primer host sano del round-robin.

        Si no queda ningún host sano, cae al primario cuando
        READ_FALLBACK_TO_PRIMARY=true; si no, re-lanza el último error.
        """
        last_exc = None
        for host in self._next_candidates():
            if not host.healthy:
                continue
            try:
                with host.pool.connection() as conn, conn.cursor() as cur:
                    cur.execute(query, params)
                    rows = cur.fetchall()
                    columns = [d.name for d in cur.description]
                host.mark_ok()
                READS_BY_NODE.labels(host=host.host).inc()
                return columns, rows
            except Exception as exc:  # noqa: BLE001 - se reintenta en otro nodo
                logger.warning("lectura falló en %s: %s", host.host, exc)
                host.mark_failed()
                last_exc = exc

        if settings.read_fallback_to_primary:
            from .main import writer_pool  # import diferido: evita ciclo

            with writer_pool.connection() as conn, conn.cursor() as cur:
                cur.execute(query, params)
                rows = cur.fetchall()
                columns = [d.name for d in cur.description]
            READS_BY_NODE.labels(host=settings.writer_db_host).inc()
            return columns, rows

        if last_exc is not None:
            raise last_exc
        raise RuntimeError("no hay hosts de lectura disponibles")

    def healthcheck(self) -> bool:
        for host in self._hosts:
            try:
                with host.pool.connection(timeout=2) as conn, conn.cursor() as cur:
                    cur.execute("SELECT 1")
                return True
            except Exception:  # noqa: BLE001
                continue
        return False


def rows_to_dicts(columns, rows):
    return [dict(zip(columns, row)) for row in rows]
