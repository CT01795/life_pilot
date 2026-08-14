import os
from threading import Lock

from sqlalchemy import Engine, create_engine


_engine: Engine | None = None
_engine_lock = Lock()


def get_database_engine() -> Engine:
    global _engine

    if _engine is not None:
        return _engine

    with _engine_lock:
        if _engine is not None:
            return _engine

        database_url = os.getenv("DB_URL", "").strip()
        if not database_url:
            raise RuntimeError("Database is not configured")

        _engine = create_engine(
            database_url,
            pool_pre_ping=True,
            pool_recycle=300,
        )
        return _engine
