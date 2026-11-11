from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    postgres_db: str = "dbscale"

    writer_db_host: str = "10.20.1.100"
    writer_db_port: int = 5432
    writer_pool_min: int = 2
    writer_pool_max: int = 10
    app_writer_user: str = "app_writer"
    app_writer_password: str = ""

    read_db_hosts: str = "10.20.1.10"
    reader_db_port: int = 5432
    reader_pool_min: int = 2
    reader_pool_max: int = 10
    app_reader_user: str = "app_reader"
    app_reader_password: str = ""

    read_fallback_to_primary: bool = False
    reader_recheck_interval_seconds: int = 5
    # Sin esto, un host de lectura inalcanzable (contenedor parado: no hay
    # RST ni ICMP, el TCP connect() simplemente no responde) cuelga cada
    # intento de conexión hasta el timeout del SO (varios minutos) o hasta
    # el timeout de 30s por defecto de psycopg_pool.getconn(), bloqueando el
    # worker de gunicorn que atendía ese request (verificado en fase 4:
    # Experimento 2, la API quedó "unhealthy" con 20 VUs de carga contra una
    # réplica recién caída). db_connect_timeout_seconds acota el connect()
    # TCP; db_get_timeout_seconds acota cuánto espera un request una
    # conexión libre del pool. Ambos cortos a propósito: la detección de
    # fallo (_FAIL_THRESHOLD) tiene que ser rápida, no silenciosa.
    db_connect_timeout_seconds: int = 2
    db_get_timeout_seconds: int = 3

    @property
    def read_hosts_list(self) -> list[str]:
        return [h.strip() for h in self.read_db_hosts.split(",") if h.strip()]

    def writer_conninfo(self) -> str:
        return (
            f"host={self.writer_db_host} port={self.writer_db_port} "
            f"dbname={self.postgres_db} user={self.app_writer_user} "
            f"password={self.app_writer_password} "
            f"connect_timeout={self.db_connect_timeout_seconds}"
        )

    def reader_conninfo(self, host: str) -> str:
        return (
            f"host={host} port={self.reader_db_port} "
            f"dbname={self.postgres_db} user={self.app_reader_user} "
            f"password={self.app_reader_password} "
            f"connect_timeout={self.db_connect_timeout_seconds}"
        )


settings = Settings()
