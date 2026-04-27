from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_host: str
    database_port: int = 5432
    database_name: str
    database_user: str
    database_password: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 30

    model_config = SettingsConfigDict(env_file=None)


settings = Settings()
