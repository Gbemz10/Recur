from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Recur API"
    environment: str = Field(default="local")
    api_v1_prefix: str = "/api/v1"
    database_url: str = "postgresql+psycopg://recur:recur@localhost:5432/recur"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


@lru_cache
def get_settings() -> Settings:
    return Settings()
