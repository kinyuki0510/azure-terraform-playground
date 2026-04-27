from contextlib import contextmanager
from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from ..config import Settings, get_settings


class SessionManager:
    def __init__(self, settings: Settings):
        self._engine = create_engine(settings.database_url)
        self._sessionLocal = sessionmaker(bind=self._engine, expire_on_commit=False)

    @contextmanager
    def get_session(self) -> Generator[Session, None, None]:
        session = self._sessionLocal()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()


@lru_cache
def get_session_manager() -> SessionManager:
    return SessionManager(get_settings())
