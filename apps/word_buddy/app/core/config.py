import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from root directory
# backend/app/core/config.py -> backend/app/core -> backend/app -> backend -> root
env_path = Path(__file__).parent.parent.parent.parent / '.env'
load_dotenv(dotenv_path=env_path)

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
FIRESTORE_DATABASE_ID = os.getenv("FIRESTORE_DATABASE_ID")
GEMINI_MODEL_NAME = os.getenv("GEMINI_MODEL_NAME")
GEMINI_ENDPOINT = os.getenv("GEMINI_ENDPOINT")
GEMINI_LOCATION = os.getenv("GEMINI_LOCATION")
