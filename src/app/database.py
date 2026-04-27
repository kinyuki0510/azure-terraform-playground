from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from settings import settings

DATABASE_URL = (
    f"postgresql://{settings.database_user}:{settings.database_password}"
    f"@{settings.database_host}:{settings.database_port}/{settings.database_name}"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
