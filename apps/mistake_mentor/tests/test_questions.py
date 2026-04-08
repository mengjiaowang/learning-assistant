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

client = TestClient(app)

# Mock user
async def override_get_current_user():
    return User(username="testuser", full_name="Test User", disabled=False)

app.dependency_overrides[get_current_user] = override_get_current_user

def test_list_questions():
    mock_query = MagicMock()
    mock_doc = MagicMock()
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unreviewed",
        "is_deleted": False,
        "tags": ["math"]
    }
    mock_query.stream.return_value = [mock_doc]
    mock_query.where.return_value = mock_query
    mock_query.order_by.return_value = mock_query
    mock_query.offset.return_value = mock_query
    mock_query.limit.return_value = mock_query
    
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/questions/")
    assert response.status_code == 200
    assert "questions" in response.json()

def test_get_question_detail():
    mock_doc_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unreviewed"
    }
    mock_doc_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_doc_ref
    
    response = client.get("/api/v1/questions/q1")
    assert response.status_code == 200
    assert response.json()["id"] == "q1"

def test_delete_question():
    mock_doc_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser"
    }
    mock_doc_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_doc_ref
    
    response = client.delete("/api/v1/questions/q1")
    assert response.status_code == 200
    assert response.json()["message"] == "错题已移入回收站"
