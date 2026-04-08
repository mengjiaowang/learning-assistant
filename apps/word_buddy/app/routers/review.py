from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.core.database import db
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/api", tags=["review"])

@router.get("/review")
async def get_review_words(book_id: str = None, path: str = None):
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        if book_id:
            docs = db.collection("books").document(book_id).collection("words").stream()
        else:
            docs = db.collection_group("words").stream()
        words = []
        for doc in docs:
            d = doc.to_dict()
            if d.get("is_deleted", False):
                continue
            path_val = d.get("path")
            if isinstance(path_val, list):
                word_path = " > ".join(path_val) if path_val else "Unclassified"
            elif isinstance(path_val, str):
                word_path = path_val
            else:
                word_path = "Unclassified"
                
            if path and word_path != path:
                continue
            words.append(d)
        return {"words": words}
    except Exception as e:
        return {"error": str(e)}

class ReviewResult(BaseModel):
    correct: bool

@router.post("/review/{word}")
async def update_review_status(word: str, result: ReviewResult, book_id: str):
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        doc_ref = db.collection("books").document(book_id).collection("words").document(word.lower())
        doc = doc_ref.get()
        
        if not doc.exists:
            return {"error": "Word not found in this book"}
            
        data = doc.to_dict()
        box = data.get("box", 1)
        
        if result.correct:
            box += 1
            days = 2 ** box
        else:
            box = 1
            days = 1
            
        next_review = datetime.now(timezone.utc) + timedelta(days=days)
        
        doc_ref.update({
            "box": box,
            "next_review": next_review,
        })
        
        from google.cloud import firestore
        db.collection("activities").add({
            "word": word,
            "correct": result.correct,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "book_id": book_id
        })
        
        return {"message": "Status updated", "box": box, "next_review": next_review}
    except Exception as e:
        return {"error": str(e)}
