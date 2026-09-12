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
    import app.routers.questions as questions_router

mock_db = questions_router.db

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

def test_upload_question_default_and_custom_grade():
    with patch('app.routers.questions.upload_to_gcs'), \
         patch('app.routers.questions.ai_service'):
        mock_doc_ref = MagicMock()
        mock_db.collection.return_value.document.return_value = mock_doc_ref
        
        # Test default grade (should be 2)
        response = client.post(
            "/api/v1/questions/upload",
            files={"file": ("test.jpg", b"fake image bytes", "image/jpeg")}
        )
        assert response.status_code == 200
        set_args = mock_doc_ref.set.call_args[0][0]
        assert set_args["grade"] == 2

        # Test custom grade (grade 1)
        response = client.post(
            "/api/v1/questions/upload",
            files={"file": ("test.jpg", b"fake image bytes", "image/jpeg")},
            data={"grade": 1}
        )
        assert response.status_code == 200
        set_args = mock_doc_ref.set.call_args[0][0]
        assert set_args["grade"] == 1

        # Test invalid grade (grade 0 or 13)
        response = client.post(
            "/api/v1/questions/upload",
            files={"file": ("test.jpg", b"fake image bytes", "image/jpeg")},
            data={"grade": 0}
        )
        assert response.status_code == 400

        response = client.post(
            "/api/v1/questions/upload",
            files={"file": ("test.jpg", b"fake image bytes", "image/jpeg")},
            data={"grade": 13}
        )
        assert response.status_code == 400

def test_list_questions_with_grade_filter():
    mock_query = MagicMock()
    mock_doc = MagicMock()
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "status": "unreviewed",
        "grade": 2,
        "is_deleted": False,
        "tags": ["math"]
    }
    mock_query.stream.return_value = [mock_doc]
    mock_query.where.return_value = mock_query
    mock_query.order_by.return_value = mock_query
    mock_query.offset.return_value = mock_query
    mock_query.limit.return_value = mock_query
    mock_db.collection.return_value = mock_query
    
    response = client.get("/api/v1/questions/?grades=1&grades=2")
    assert response.status_code == 200
    assert "questions" in response.json()

def test_update_question_grade():
    mock_doc_ref = MagicMock()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "testuser",
        "grade": 2
    }
    mock_doc_ref.get.return_value = mock_doc
    mock_db.collection.return_value.document.return_value = mock_doc_ref
    
    # Success
    response = client.post("/api/v1/questions/q1/grade", json={"grade": 1})
    assert response.status_code == 200
    assert response.json()["grade"] == 1
    mock_doc_ref.update.assert_called_with({"grade": 1}, timeout=10)

    # Invalid grade
    response = client.post("/api/v1/questions/q1/grade", json={"grade": 0})
    assert response.status_code == 400

    # Unauthorized
    mock_doc.to_dict.return_value = {
        "id": "q1",
        "user_id": "otheruser",
        "grade": 2
    }
    response = client.post("/api/v1/questions/q1/grade", json={"grade": 1})
    assert response.status_code == 403

def test_migrate_grades():
    mock_query = MagicMock()
    mock_doc1 = MagicMock()
    mock_doc1.to_dict.return_value = {"id": "q1", "user_id": "testuser"}
    mock_doc2 = MagicMock()
    mock_doc2.to_dict.return_value = {"id": "q2", "user_id": "testuser", "grade": 2}
    mock_query.stream.return_value = [mock_doc1, mock_doc2]
    mock_query.where.return_value = mock_query
    mock_db.collection.return_value = mock_query

    mock_batch = MagicMock()
    mock_db.batch.return_value = mock_batch

    # force=False: only q1 without grade is updated
    response = client.post("/api/v1/questions/migrate-grades?target_grade=1&force=false")
    assert response.status_code == 200
    assert response.json()["updated_count"] == 1

    # Invalid target_grade (0)
    response = client.post("/api/v1/questions/migrate-grades?target_grade=0")
    assert response.status_code == 422
