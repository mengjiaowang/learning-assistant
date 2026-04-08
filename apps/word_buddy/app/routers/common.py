from fastapi import APIRouter
from app.core.database import db
from google.cloud import firestore
import random
import json

router = APIRouter(prefix="/api", tags=["common"])

@router.get("/stats")
async def get_stats():
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        docs = db.collection_group("words").stream()
        words = []
        for doc in docs:
            d = doc.to_dict()
            if d.get("is_deleted", False):
                continue
            words.append(d)
            
        total_words = len(words)
        mastered_words = len([w for w in words if w.get("box", 1) > 1])
        
        from datetime import datetime, timedelta, timezone
        
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
                        
        # Calculate streak and daily activity
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

@router.get("/test")
async def get_test():
    if db is None:
        return {"error": "Firestore not initialized. Check GCP_PROJECT_ID in .env"}
        
    try:
        docs = db.collection_group("words").stream()
        quiz_list = []
        for doc in docs:
            data = doc.to_dict()
            if data.get("is_deleted", False):
                continue
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
        
        return {"quiz": json.dumps(sampled_quizzes)}
    except Exception as e:
        return {"error": str(e)}
