from typing import List
from functools import lru_cache
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
import os
import json


# -------------------------- PATH ANCHOR --------------------------

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
ENV_PATH = os.path.join(BASE_DIR, ".env")


class Settings(BaseSettings):
    # ------------------------ MODEL CONFIG ------------------------
    model_config = SettingsConfigDict(
        env_file=ENV_PATH,
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    # -------------------------- APPLICATION --------------------------
    app_name: str = "BoleylaPanel"
    app_version: str = "1.0.0"
    app_env: str = "development"
    debug: bool = True
    host: str = "0.0.0.0"
    port: int = 8000

    # -------------------------- DATABASE --------------------------
    DATABASE_URL: str | None = None  # Full URL (Production)
    db_host: str = "localhost"
    db_port: int = 3306
    db_name: str = "boleylapanel"
    db_user: str = "boleyla"
    db_password: str = "StrongPassword123"

    # -------------------------- CORS --------------------------
    cors_origins: str = '["http://localhost:3000"]'

    # -------------------------- JWT SETTINGS --------------------------
    SECRET_KEY: str = Field(
        default="your-secret-key-change-in-production",
        description="Secret key for JWT encoding"
    )
    ALGORITHM: str = Field(
        default="HS256",
        description="JWT signing algorithm"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(
        default=30,
        description="Access token expiration time in minutes"
    )

    # -------------------------- XRAY SETTINGS --------------------------
    XRAY_SERVICE_NAME: str = "xray"
    XRAY_BASE_PORT: int = 10000
    ENABLE_XRAY_SERVICE: bool = True


    XRAY_CONFIG_TEMPLATE_PATH: str = "xray/config_template.json"


    XRAY_CONFIG_OUTPUT_PATH: str = "xray/output_configs"

    # -------------------------- VALIDATORS --------------------------
    @field_validator("cors_origins")
    @classmethod
    def parse_cors_origins(cls, v: str) -> List[str]:
        if isinstance(v, str):
            try:
                return json.loads(v)
            except json.JSONDecodeError:
                return [v]
        return v

    # -------------------------- PROPERTIES --------------------------
    @property
    def cors_origins_list(self) -> List[str]:
        return self.cors_origins

    @property
    def database_url(self) -> str:
        """
        Priority:
        1) DATABASE_URL env (Production)
        2) Construct from parts (Dev)
        """
        if self.DATABASE_URL:
            return self.DATABASE_URL

        return (
            f"mysql+pymysql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
            f"?charset=utf8mb4"
        )

    def is_production(self) -> bool:
        return self.app_env.lower() == "production"

    def is_development(self) -> bool:
        return self.app_env.lower() == "development"


# ----------------------- GLOBAL SETTINGS INSTANCE -----------------------
@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
