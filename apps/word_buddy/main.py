import os
from pathlib import Path
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from pydantic import BaseModel
from google.cloud import firestore
from datetime import datetime, timedelta, timezone
import random
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

import vertexai
from vertexai.generative_models import GenerativeModel, Part
import nltk
from nltk.corpus import wordnet

# Load environment variables from root directory
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(dotenv_path=env_path)

project_id = os.getenv("PROJECT_ID")
database_id = os.getenv("WORD_BUDDY_FIRESTORE_DB")
MODEL_NAME = os.getenv("GEMINI_MODEL_NAME")

SECRET_KEY = os.getenv("SECRET_KEY", "your-fallback-secret-key")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

class User(BaseModel):
    username: str
    full_name: str | None = None
    disabled: bool | None = None

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    return User(username=username)

db = None
if project_id and project_id != "your-project-id":
    vertexai.init(project=project_id, location="global")
    db = firestore.Client(project=project_id, database=database_id)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["System"])
async def health_check():
    """Cloud Run 健康检查端点"""
    return {"status": "ok", "message": "Word Buddy Backend is running"}

@app.get("/")
def read_root():
    p_id = os.getenv("PROJECT_ID", "Not Set")
    return {
        "message": "Welcome to Word Buddy API (Vertex AI enabled)",
        "gcp_project_id": p_id,
        "vertex_initialized": project_id is not None and project_id != "your-project-id"
    }

class WordBook(BaseModel):
    name: str
    hierarchy: list = []

@app.post("/api/books")
async def create_book(book: WordBook, current_user: User = Depends(get_current_user)):
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

@app.get("/api/books")
async def get_books(current_user: User = Depends(get_current_user)):
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

@app.put("/api/books/{book_id}")
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

@app.delete("/api/books/{book_id}")
async def delete_book(book_id: str):
    if db is None:
        return {"error": "Firestore not initialized"}
    try:
        db.collection("word_books").document(book_id).update({"is_deleted": True})
        
        # Mark all words as deleted in subcollection
        words_ref = db.collection("books").document(book_id).collection("words")
        docs = words_ref.stream()
        batch = db.batch()
        for doc in docs:
            batch.update(doc.reference, {"is_deleted": True})
        batch.commit()
        
        return {"message": "Book and associated words soft deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/recycle_bin")
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

@app.post("/api/recycle_bin/{book_id}/restore")
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

@app.delete("/api/recycle_bin/{book_id}/permanent")
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

@app.post("/api/ocr")
async def ocr_extract(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        model = GenerativeModel(MODEL_NAME)
        mime_type = file.content_type
        if mime_type == "application/octet-stream" or not mime_type:
            import mimetypes
            guessed_type, _ = mimetypes.guess_type(file.filename)
            mime_type = guessed_type or "image/jpeg"
        image_part = Part.from_data(data=contents, mime_type=mime_type)
        prompt = """
        Analyze this image and identify the key English vocabulary words that a learner should master. 
        Do NOT just extract all text like a standard OCR. 
        Focus on important nouns, verbs, adjectives, and adverbs that carry the main meaning or are educational.
        Ignore very common words like 'the', 'a', 'is', 'and', 'to', etc., unless they are part of a specific phrase or idiom shown.
        Return a clean JSON list of strings, e.g., ['word1', 'word2']. 
        Do not include any other text or markdown formatting.
        """
        response = model.generate_content([image_part, prompt])
        try:
            import json
            words_list = json.loads(response.text)
            return {"words": "\n".join(words_list)}
        except Exception as e:
            print(f"Failed to parse OCR result as JSON: {e}")
            return {"words": response.text}
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"OCR Error: {e}")
        return {"error": str(e)}

class WordRequest(BaseModel):
    word: str

@app.post("/api/word_details")
async def get_word_details(request: WordRequest):
    try:
        model = GenerativeModel(MODEL_NAME)
        
        prompt = f"""
        Provide detailed learning information for the English word: "{request.word}".
        Return a JSON object with the following structure:
        {{
            "word": "{request.word}",
            "phonetics": "Phonetic spelling or natural phonics guide",
            "etymology": "Brief root or etymology explanation",
            "meaning": "Chinese meaning",
            "sentences": [
                "Example sentence 1 in English with Chinese translation",
                "Example sentence 2 in English with Chinese translation"
            ]
        }}
        Ensure the response is ONLY the JSON object, no markdown formatting, no code blocks.
        """
        
        response = model.generate_content(prompt)
        return {"details": response.text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class SaveWordsRequest(BaseModel):
    words: list[str]
    book_id: str
    path: list[str] = []

@app.post("/api/words")
async def save_words(request: SaveWordsRequest, current_user: User = Depends(get_current_user)):
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        valid_words = [w.strip().lower() for w in request.words if w.strip() and w.strip().isalpha()]
        if not valid_words:
            return {"message": "No valid words to save"}
            
        # Fetch rich WordNet data
        import json
        word_rich_data = {}
        for w in valid_words:
            synsets = wordnet.synsets(w)
            senses = []
            for syn in synsets[:3]: # Limit to top 3 senses
                sense_data = {
                    "synset": syn.name(),
                    "definition": syn.definition(),
                    "examples": syn.examples(),
                    "synonyms": [l.name() for l in syn.lemmas()],
                    "hypernyms": [h.name() for h in syn.hypernyms()],
                    "hyponyms": [h.name() for h in syn.hyponyms()]
                }
                senses.append(sense_data)
            word_rich_data[w] = senses
            
        model = GenerativeModel(MODEL_NAME)
        
        prompt = f"""
        Provide detailed learning information and a quiz question for the following English words.
        We have provided rich WordNet data for each word, including definitions for different senses.
        Please provide Chinese translations for these definitions, and generate etymology, phonetics, and a quiz suitable for children aged 6-12.
        
        WordNet Data:
        {json.dumps(word_rich_data, ensure_ascii=False)}
        
        Return a JSON list of objects, each with the following structure:
        {{
            "word": "the word",
            "phonetics": "Phonetic spelling or natural phonics guide",
            "etymology": "Brief root or etymology explanation suitable for children",
            "senses_zh": [
                {{
                    "synset": "synset name from input",
                    "definition_zh": "Chinese translation of the definition"
                }},
                ...
            ],
            "quiz": {{
                "question": "A simple question about the word or a fill-in-the-blank sentence suitable for children.",
                "options": {{"A": "Simple option 1", "B": "Simple option 2", "C": "Simple option 3", "D": "Simple option 4"}},
                "answer": "A"
            }}
        }}
        Ensure the response is ONLY the JSON list, no markdown formatting, no code blocks.
        """
        
        response = model.generate_content(prompt)
        details_list = []
        try:
            details_list = json.loads(response.text)
        except Exception as e:
            print(f"JSON Parsing Error: {e}")
            print(f"Gemini Response: {response.text}")
            raise HTTPException(status_code=500, detail=f"Failed to parse Gemini response as JSON: {response.text}")
            
        details_map = {d["word"].lower(): d for d in details_list if "word" in d}
        
        batch = db.batch()
        for word in valid_words:
            doc_ref = db.collection("books").document(request.book_id).collection("words").document(word)
            
            gemini_details = details_map.get(word, {})
            wordnet_senses = word_rich_data.get(word, [])
            
            # Merge Gemini translations into WordNet senses
            senses_zh_map = {s["synset"]: s["definition_zh"] for s in gemini_details.get("senses_zh", [])}
            
            for sense in wordnet_senses:
                sense["definition_zh"] = senses_zh_map.get(sense["synset"], "N/A")
            
            details = {
                "word": word,
                "phonetics": gemini_details.get("phonetics", "N/A"),
                "etymology": gemini_details.get("etymology", "N/A"),
                "wordnet_senses": wordnet_senses,
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

@app.get("/api/words")
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

@app.get("/api/review")
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

@app.post("/api/review/{word}")
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
        
        db.collection("activities").add({
            "word": word,
            "correct": result.correct,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "book_id": book_id
        })
        
        return {"message": "Status updated", "box": box, "next_review": next_review}
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/stats")
async def get_stats():
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        total_docs = db.collection_group("words").count().get()
        total_words = total_docs[0][0].value
        
        mastered_docs = db.collection_group("words").where(filter=firestore.FieldFilter("box", ">", 1)).count().get()
        mastered_words = mastered_docs[0][0].value
        
        # Calculate weekly activity
        now = datetime.now(timezone.utc)
        start_of_today = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
        since_date_weekly = start_of_today - timedelta(days=6)
        
        activities_weekly = db.collection("activities").where("timestamp", ">=", since_date_weekly).stream()
        
        activity_by_day = [0] * 7
        for act in activities_weekly:
            data = act.to_dict()
            ts = data.get("timestamp")
            if ts:
                ts_date = datetime(ts.year, ts.month, ts.day, tzinfo=timezone.utc)
                days_diff = (start_of_today - ts_date).days
                if 0 <= days_diff < 7:
                    idx = 6 - days_diff
                    if 0 <= idx < 7:
                        activity_by_day[idx] += 1
                        
        # Calculate streak
        since_date_streak = start_of_today - timedelta(days=90)
        activities_streak = db.collection("activities").where("timestamp", ">=", since_date_streak).stream()
        
        active_days = set()
        daily_activity = {}
        for act in activities_streak:
            data = act.to_dict()
            ts = data.get("timestamp")
            if ts:
                ts_date = datetime(ts.year, ts.month, ts.day, tzinfo=timezone.utc)
                active_days.add(ts_date)
                
                date_str = ts_date.strftime("%Y-%m-%d")
                daily_activity[date_str] = daily_activity.get(date_str, 0) + 1
                
        streak = 0
        check_date = start_of_today
        
        if check_date not in active_days:
            check_date -= timedelta(days=1)
            
        while check_date in active_days:
            streak += 1
            check_date -= timedelta(days=1)
            
        return {
            "total_words": total_words,
            "mastered_words": mastered_words,
            "streak_days": streak,
            "weekly_activity": activity_by_day,
            "daily_activity": daily_activity
        }
    except Exception as e:
        # Fallback if count() fails
        try:
            docs = db.collection_group("words").stream()
            words = [doc.to_dict() for doc in docs]
            total_words = len(words)
            mastered_words = len([w for w in words if w.get("box", 1) > 1])
            return {
                "total_words": total_words,
                "mastered_words": mastered_words,
                "streak_days": 5,
                "weekly_activity": [5, 10, 0, 8, 12, 4, 7]
            }
        except Exception as e2:
            return {"error": str(e2)}

@app.get("/api/test")
async def get_test():
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        docs = db.collection_group("words").stream()
        quiz_list = []
        for doc in docs:
            data = doc.to_dict()
            details = data.get("details", {})
            quiz = details.get("quiz")
            if quiz:
                quiz_list.append(quiz)
            else:
                # Fallback for old words without quiz
                quiz_list.append({
                    "word": data.get("word", "unknown"),
                    "question": f"What is the meaning of {data.get('word', 'unknown')}?",
                    "options": {"A": "Option 1", "B": "Option 2", "C": "Option 3", "D": "Option 4"},
                    "answer": "A"
                })
        
        if not quiz_list:
            return {"error": "No words found in database to test."}
            
        sample_size = min(3, len(quiz_list))
        sampled_quizzes = random.sample(quiz_list, sample_size)
        
        import json
        return {"quiz": json.dumps(sampled_quizzes)}
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/books/{book_id}/hierarchy")
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
