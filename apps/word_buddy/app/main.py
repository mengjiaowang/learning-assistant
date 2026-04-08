from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import books, words, review, common, recycle_bin
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(books.router)
app.include_router(words.router)
app.include_router(review.router)
app.include_router(common.router)
app.include_router(recycle_bin.router)

@app.get("/")
def read_root():
    p_id = os.getenv("GCP_PROJECT_ID", "Not Set")
    return {
        "message": "Welcome to Word Buddy API (Modularized)",
        "gcp_project_id": p_id,
    }
