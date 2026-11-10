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

    @property
    def read_hosts_list(self) -> list[str]:
        return [h.strip() for h in self.read_db_hosts.split(",") if h.strip()]

    def writer_conninfo(self) -> str:
        return (
            f"host={self.writer_db_host} port={self.writer_db_port} "
            f"dbname={self.postgres_db} user={self.app_writer_user} "
            f"password={self.app_writer_password}"
        )

    def reader_conninfo(self, host: str) -> str:
        return (
            f"host={host} port={self.reader_db_port} "
            f"dbname={self.postgres_db} user={self.app_reader_user} "
            f"password={self.app_reader_password}"
        )


settings = Settings()
