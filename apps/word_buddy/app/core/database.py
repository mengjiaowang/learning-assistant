from google.cloud import firestore
import vertexai
from app.core.config import PROJECT_ID, FIRESTORE_DATABASE_ID, GEMINI_ENDPOINT, GEMINI_LOCATION

db = None

if PROJECT_ID and PROJECT_ID != "your-project-id":
    vertexai.init(project=PROJECT_ID, location=GEMINI_LOCATION, api_endpoint=GEMINI_ENDPOINT)
    db = firestore.Client(project=PROJECT_ID, database=FIRESTORE_DATABASE_ID)
