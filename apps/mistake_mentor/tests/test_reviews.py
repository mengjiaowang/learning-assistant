import pytest
from fastapi.testclient import TestClient
import sys
import os
from unittest.mock import patch, MagicMock

# Add the backend directory to the path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Mock firestore client BEFORE importing anything from app
mock_db = MagicMock()
mock_storage = MagicMock()

with patch('google.cloud.firestore.Client', return_value=mock_db), \
     patch('google.cloud.storage.Client', return_value=mock_storage):
    from app.main import app, User, get_current_user
    import app.routers.reviews as reviews_router

mock_db = reviews_router.db

client = TestClient(app)

# Mock user
async def override_get_current_user():
    return User(username="testuser", full_name="Test User", disabled=False)

app.dependency_overrides[get_current_user] = override_get_current_user

def test_get_review_batch():
    # Mock Firestore query chain
    mock_query = MagicMock()
    mock_doc = MagicMock()
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unreviewed",
        "is_deleted": False,
        "tags": ["math"],
        "created_at": "2026-04-08T12:00:00Z"
    }
    mock_query.stream.return_value = [mock_doc]
    mock_query.where.return_value = mock_query
    mock_query.limit.return_value = mock_query
    
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/reviews/batch")
    assert response.status_code == 200
    assert "questions" in response.json()
    assert len(response.json()["questions"]) == 1

def test_get_free_batch():
    mock_query = MagicMock()
    mock_doc = MagicMock()
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unmastered",
        "is_deleted": False,
        "tags": ["math"]
    }
    mock_query.stream.return_value = [mock_doc]
    mock_query.where.return_value = mock_query
    mock_query.limit.return_value = mock_query
    
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/reviews/free")
    assert response.status_code == 200
    assert "questions" in response.json()

def test_submit_review():
    mock_doc_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "current_interval": 1,
        "status": "unreviewed"
    }
    mock_doc_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_doc_ref
    
    response = client.post("/api/v1/reviews/q1", json={"feedback": "mastered"})
    assert response.status_code == 200
    assert response.json()["message"] == "Review recorded successfully"

def test_get_review_batch_with_grades():
    mock_query = MagicMock()
    mock_doc = MagicMock()
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unreviewed",
        "grade": 2,
        "is_deleted": False,
        "tags": ["math"],
        "created_at": "2026-04-08T12:00:00Z"
    }
    mock_query.stream.return_value = [mock_doc]
    mock_query.where.return_value = mock_query
    mock_query.limit.return_value = mock_query
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/reviews/batch?grades=2")
    assert response.status_code == 200
    assert len(response.json()["questions"]) == 1

def test_get_free_batch_with_grades():
    mock_query = MagicMock()
    mock_doc = MagicMock()
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unmastered",
        "grade": 1,
        "is_deleted": False,
        "tags": ["math"]
    }
    mock_query.stream.return_value = [mock_doc]
    mock_query.where.return_value = mock_query
    mock_query.limit.return_value = mock_query
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/reviews/free?grades=1")
    assert response.status_code == 200
    assert len(response.json()["questions"]) == 1

def test_get_statistics_with_grades():
    mock_query = MagicMock()
    mock_doc1 = MagicMock()
    mock_doc1.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "mastered",
        "grade": 1,
        "is_deleted": False,
        "tags": ["数学"],
        "created_at": "2026-04-08T12:00:00Z",
        "review_history": []
    }
    mock_doc2 = MagicMock()
    mock_doc2.to_dict.return_value = {
        "id": "q2",
        "user_id": "testuser",
        "status": "unmastered",
        "grade": 2,
        "is_deleted": False,
        "tags": ["语文"],
        "created_at": "2026-04-08T12:00:00Z",
        "review_history": []
    }
    mock_query.stream.return_value = [mock_doc1, mock_doc2]
    mock_query.where.return_value = mock_query
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/reviews/statistics")
    assert response.status_code == 200
    data = response.json()
    assert "grades" in data
    assert "一年级" in data["grades"]
    assert "二年级" in data["grades"]
    assert data["grades"]["一年级"]["total"] == 1
    assert data["grades"]["二年级"]["total"] == 1
