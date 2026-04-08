from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
import os
from pathlib import Path

# 动态获取项目根目录下的 .env 文件路径
# __file__ 是 apps/mistake_mentor/app/config.py
# parent 是 app/
# parent.parent 是 mistake_mentor/
# parent.parent.parent 是 apps/
# parent.parent.parent.parent 是项目根目录
_current_dir = Path(__file__).resolve().parent
_root_env = _current_dir.parent.parent.parent / ".env"

class Settings(BaseSettings):
    # GCP Configuration
    PROJECT_ID: str = "learning-assistant-490905"
    MISTAKE_MENTOR_FIRESTORE_DB: str = "mistake-mentor-db"
    
    # Model Names
    ERASURE_MODEL: str = "gemini-3.1-flash-image-preview"
    GEMINI_MODEL_NAME: str = "gemini-3.1-pro-preview"
    
    # Backend Security
    SECRET_KEY: str = "SUPER_SECRET_KEY_FOR_DEMO_PURPOSES"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours
    ADMIN_PASSWORD: str = "admin123" # 默认初始密码
    ADMIN_USERNAME: str = "admin" # 默认初始用户名

    # 允许从环境变量加载，优先读取项目根目录的 .env
    model_config = SettingsConfigDict(
        env_file=(".env", str(_root_env)), 
        env_file_encoding="utf-8",
        extra="ignore" 
    )

settings = Settings()
