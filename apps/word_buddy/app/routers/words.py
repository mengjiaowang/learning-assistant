from fastapi import APIRouter, File, UploadFile, HTTPException
from pydantic import BaseModel
from app.core.database import db
from google.cloud import firestore
from app.services.gemini import analyze_image, generate_word_details, generate_rich_word_details
from app.services.wordnet import get_wordnet_data
import json

router = APIRouter(prefix="/api", tags=["words"])

@router.post("/ocr")
async def ocr_extract(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        mime_type = file.content_type
        if mime_type == "application/octet-stream" or not mime_type:
            import mimetypes
            guessed_type, _ = mimetypes.guess_type(file.filename)
            mime_type = guessed_type or "image/jpeg"
            
        text = analyze_image(contents, mime_type)
        try:
            words_list = json.loads(text)
            return {"words": "\n".join(words_list)}
        except Exception as e:
            print(f"Failed to parse OCR result as JSON: {e}")
            return {"words": text}
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"OCR Error: {e}")
        return {"error": str(e)}

class WordRequest(BaseModel):
    word: str

@router.post("/word_details")
async def get_word_details_endpoint(request: WordRequest):
    try:
        text = generate_word_details(request.word)
        return {"details": text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class SaveWordsRequest(BaseModel):
    words: list[str]
    book_id: str
    path: list[str] = []

@router.post("/words")
async def save_words(request: SaveWordsRequest):
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        valid_words = [w.strip().lower() for w in request.words if w.strip() and w.strip().isalpha()]
        if not valid_words:
            return {"message": "No valid words to save"}
            
        # Generate Gemini details
        response_text = generate_rich_word_details(valid_words)
        
        details_list = []
        try:
            details_list = json.loads(response_text)
        except Exception as e:
            print(f"JSON Parsing Error: {e}")
            print(f"Gemini Response: {response_text}")
            raise HTTPException(status_code=500, detail=f"Failed to parse Gemini response as JSON: {response_text}")
            
        details_map = {d["word"].lower(): d for d in details_list if "word" in d}
        
        batch = db.batch()
        for word in valid_words:
            doc_ref = db.collection("books").document(request.book_id).collection("words").document(word)
            
            gemini_details = details_map.get(word, {})
            
            details = {
                "word": word,
                "phonetics": gemini_details.get("phonetics", {"uk": "N/A", "us": "N/A"}),
                "forms": gemini_details.get("forms", {}),
                "explanations": gemini_details.get("explanations", []),
                "synonyms": gemini_details.get("synonyms", []),
                "antonyms": gemini_details.get("antonyms", []),
                "sentences": gemini_details.get("sentences", []),
                "quiz": gemini_details.get("quiz", {
                    "question": f"What is the meaning of {word}?",
                    "options": {"A": "Option 1", "B": "Option 2", "C": "Option 3", "D": "Option 4"},
                    "answer": "A"
                })
            }
            
            batch.set(doc_ref, {
                "word": word,
                "book_id": request.book_id,
                "path": request.path,
                "created_at": firestore.SERVER_TIMESTAMP,
                "next_review": firestore.SERVER_TIMESTAMP,
                "box": 1,
                "details": details
            })
        batch.commit()
        return {"message": f"Successfully saved {len(valid_words)} words with details"}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/words")
async def get_words(book_id: str = None):
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        if book_id:
            docs = db.collection("books").document(book_id).collection("words").stream()
        else:
            docs = db.collection_group("words").stream()
        words = []
        for doc in docs:
            words.append(doc.to_dict())
        return {"words": words}
    except Exception as e:
        return {"error": str(e)}
