from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.core.database import db
from google.cloud import firestore

router = APIRouter(prefix="/api/books", tags=["books"])

class WordBook(BaseModel):
    name: str
    hierarchy: list = []

@router.post("")
async def create_book(book: WordBook):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        doc_ref = db.collection("word_books").document()
        doc_ref.set({
            "name": book.name,
            "hierarchy": book.hierarchy,
            "created_at": firestore.SERVER_TIMESTAMP
        })
        return {"id": doc_ref.id, "message": "Book created"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("")
async def get_books():
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        docs = db.collection("word_books").stream()
        books = []
        for doc in docs:
            d = doc.to_dict()
            if d.get("is_deleted", False):
                continue
            word_count = db.collection("books").document(doc.id).collection("words").count().get()[0][0].value
            books.append({
                "id": doc.id,
                "name": d.get("name"),
                "hierarchy": d.get("hierarchy", []),
                "created_at": d.get("created_at"),
                "word_count": word_count
            })
        return {"books": books}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{book_id}")
async def update_book(book_id: str, book: WordBook):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        doc_ref = db.collection("word_books").document(book_id)
        doc_ref.update({
            "name": book.name,
            "hierarchy": book.hierarchy
        })
        return {"message": "Book updated"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{book_id}")
async def delete_book(book_id: str):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        db.collection("word_books").document(book_id).update({"is_deleted": True})
        
        words_ref = db.collection("books").document(book_id).collection("words")
        docs = words_ref.stream()
        batch = db.batch()
        for doc in docs:
            batch.update(doc.reference, {"is_deleted": True})
        batch.commit()
        
        return {"message": "Book and associated words soft deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{book_id}/hierarchy")
async def get_book_hierarchy(book_id: str):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        words_ref = db.collection("books").document(book_id).collection("words")
        docs = words_ref.stream()
        
        hierarchy_counts = {}
        for doc in docs:
            d = doc.to_dict()
            if d.get("is_deleted", False):
                continue
            path_val = d.get("path")
            if isinstance(path_val, list):
                path = " > ".join(path_val) if path_val else "Unclassified"
            elif isinstance(path_val, str):
                path = path_val
            else:
                path = "Unclassified"
            hierarchy_counts[path] = hierarchy_counts.get(path, 0) + 1
            
        result = [{"name": k, "word_count": v} for k, v in hierarchy_counts.items()]
        return {"hierarchy": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
