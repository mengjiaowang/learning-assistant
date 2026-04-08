from fastapi import APIRouter, HTTPException
from app.core.database import db
from google.cloud import firestore

router = APIRouter(prefix="/api/recycle_bin", tags=["recycle_bin"])

@router.get("")
async def get_recycle_bin():
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        docs = db.collection("word_books").stream()
        books = []
        for doc in docs:
            d = doc.to_dict()
            if d.get("is_deleted", False):
                books.append({
                    "id": doc.id,
                    "name": d.get("name"),
                    "hierarchy": d.get("hierarchy", []),
                    "created_at": d.get("created_at")
                })
        return {"books": books}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{book_id}/restore")
async def restore_book(book_id: str):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        db.collection("word_books").document(book_id).update({"is_deleted": False})
        
        # Restore all words in subcollection
        words_ref = db.collection("books").document(book_id).collection("words")
        docs = words_ref.stream()
        batch = db.batch()
        for doc in docs:
            batch.update(doc.reference, {"is_deleted": False})
        batch.commit()
        
        return {"message": "Book and associated words restored"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{book_id}/permanent")
async def permanent_delete_book(book_id: str):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        db.collection("word_books").document(book_id).delete()
        
        # Permanently delete all words in subcollection
        words_ref = db.collection("books").document(book_id).collection("words")
        docs = words_ref.stream()
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        
        return {"message": "Book and associated words permanently deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
