"""
Application Settings using Pydantic Settings v2
"""

from typing import List
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    # Application Settings
    app_name: str = Field(default="BoleylaPanel", description="Application name")
    app_version: str = Field(default="1.0.0", description="Application version")
    app_env: str = Field(default="development", description="Environment (development/production)")
    debug: bool = Field(default=False, description="Debug mode")

    # Server Settings
    host: str = Field(default="0.0.0.0", description="Server host")
    port: int = Field(default=8000, description="Server port")

    # Database Settings
    db_host: str = Field(default="localhost", description="Database host")
    db_port: int = Field(default=3306, description="Database port")
    db_user: str = Field(default="root", description="Database user")
    db_password: str = Field(default="", description="Database password")
    db_name: str = Field(default="boleylapanel", description="Database name")
    db_echo: bool = Field(default=False, description="SQLAlchemy echo SQL queries")

    # Security Settings
    secret_key: str = Field(
        default="please_change_this_secret_key_in_production",
        description="Secret key for JWT encoding"
    )
    algorithm: str = Field(default="HS256", description="JWT algorithm")
    access_token_expire_minutes: int = Field(
        default=30,
        description="Access token expiration time in minutes"
    )

    # CORS Settings
    cors_origins: str = Field(
        default="http://localhost:3000,http://localhost:8080",
        description="Comma-separated list of allowed CORS origins"
    )

    # Redis Settings
    redis_host: str = Field(default="localhost", description="Redis host")
    redis_port: int = Field(default=6379, description="Redis port")
    redis_db: int = Field(default=0, description="Redis database number")

    # File Upload Settings
    max_upload_size: int = Field(
        default=10485760,
        description="Maximum upload size in bytes (default: 10MB)"
    )
    allowed_extensions: str = Field(
        default="json,conf,txt",
        description="Comma-separated list of allowed file extensions"
    )

    # Logging Settings
    log_level: str = Field(default="INFO", description="Logging level")
    log_file: str = Field(default="logs/app.log", description="Log file path")

    # Backup Settings
    backup_enabled: bool = Field(default=True, description="Enable automatic backups")
    backup_retention_days: int = Field(
        default=7,
        description="Number of days to retain backups"
    )
    backup_path: str = Field(default="/backups", description="Backup directory path")

    # Pydantic Settings Configuration
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    @field_validator("app_env")
    @classmethod
    def validate_environment(cls, v: str) -> str:
        """Validate environment value"""
        allowed = ["development", "production", "staging", "testing"]
        if v.lower() not in allowed:
            raise ValueError(f"app_env must be one of {allowed}")
        return v.lower()

    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v: str) -> str:
        """Validate log level"""
        allowed = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v.upper() not in allowed:
            raise ValueError(f"log_level must be one of {allowed}")
        return v.upper()

    @field_validator("secret_key")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Validate secret key length"""
        if len(v) < 32:
            raise ValueError("secret_key must be at least 32 characters long")
        return v

    @property
    def database_url(self) -> str:
        """Generate database URL for SQLAlchemy"""
        return (
            f"mysql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    @property
    def async_database_url(self) -> str:
        """Generate async database URL for SQLAlchemy"""
        return (
            f"mysql+aiomysql://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )

    @property
    def redis_url(self) -> str:
        """Generate Redis URL"""
        return f"redis://{self.redis_host}:{self.redis_port}/{self.redis_db}"

    @property
    def cors_origins_list(self) -> List[str]:
        """Parse CORS origins into a list"""
        return [origin.strip() for origin in self.cors_origins.split(",")]

    @property
    def allowed_extensions_list(self) -> List[str]:
        """Parse allowed extensions into a list"""
        return [ext.strip() for ext in self.allowed_extensions.split(",")]

    def is_production(self) -> bool:
        """Check if running in production environment"""
        return self.app_env == "production"

    def is_development(self) -> bool:
        """Check if running in development environment"""
        return self.app_env == "development"


# Create global settings instance
settings = Settings()
