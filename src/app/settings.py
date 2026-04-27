from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict

_MASKED = "***"
_SENSITIVE_FIELDS = {"jwt_secret", "database_url"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60

    database_url: str

    def safe_dump(self) -> dict:
        return {
            k: _MASKED if k in _SENSITIVE_FIELDS else v
            for k, v in self.model_dump().items()
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
