from typing import List, ClassVar
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
import json


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    # Application
    app_name: str = "BoleylaPanel"
    app_version: str = "1.0.0"
    app_env: str = "development"
    debug: bool = True
    host: str = "127.0.0.1"
    port: int = 8000

    # Database
    db_host: str = "localhost"
    db_port: int = 3306
    db_name: str = "boleylapanel"
    db_user: str = "boleyla"
    db_password: str = "StrongPassword123"

    # CORS
    cors_origins: str = '["http://localhost:3000"]'

    # JWT Settings (⚡ نسخه کاملاً صحیح و هماهنگ با auth.py)
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

    # XRAY Specific Settings
    XRAY_CONFIG_TEMPLATE_PATH: ClassVar[str] = "xray/config_template.json"
    XRAY_CONFIG_OUTPUT_PATH: ClassVar[str] = "xray/output_configs"
    XRAY_SERVICE_NAME: str = "xray"
    XRAY_BASE_PORT: int = 10000
    ENABLE_XRAY_SERVICE: bool = True

    # You might also want to add a base port for Xray clients

    # ---- Validators ----

    @field_validator("cors_origins")
    @classmethod
    def parse_cors_origins(cls, v: str) -> List[str]:
        if isinstance(v, str):
            try:
                return json.loads(v)
            except json.JSONDecodeError:
                return [v]
        return v

    # ---- Properties ----

    @property
    def cors_origins_list(self) -> List[str]:
        return self.cors_origins

    @property
    def database_url(self) -> str:
        """
        Generate database URL for PyMySQL
        Format: mysql+pymysql://user:password@host:port/database
        """
        return (
            f"mysql+pymysql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
            f"?charset=utf8mb4"
        )

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
