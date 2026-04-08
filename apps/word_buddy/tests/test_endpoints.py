import pytest
from fastapi.testclient import TestClient
import sys
import os
from unittest.mock import patch, MagicMock

# Add the apps directory to the path so we can import main
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app, User, get_current_user

client = TestClient(app)

# Mock authentication dependency
async def override_get_current_user():
    return User(username="testuser")

app.dependency_overrides[get_current_user] = override_get_current_user

def test_get_books():
    with patch('main.db') as mock_db:
        mock_doc = MagicMock()
        mock_doc.to_dict.return_value = {"name": "Test Book", "hierarchy": [], "is_deleted": False}
        mock_doc.id = "test_id"
        
        mock_db.collection.return_value.stream.return_value = [mock_doc]
        
        # Mock word count
        mock_count_result = MagicMock()
        mock_count_result.value = 5
        mock_db.collection.return_value.document.return_value.collection.return_value.count.return_value.get.return_value = [[mock_count_result]]
        
        response = client.get("/api/books")
        assert response.status_code == 200
        assert "books" in response.json()
        assert len(response.json()["books"]) == 1
        assert response.json()["books"][0]["name"] == "Test Book"

def test_create_book():
    with patch('main.db') as mock_db:
        mock_doc_ref = MagicMock()
        mock_doc_ref.id = "new_id"
        mock_db.collection.return_value.document.return_value = mock_doc_ref
        
        response = client.post("/api/books", json={"name": "New Book", "hierarchy": []})
        assert response.status_code == 200
        assert response.json()["id"] == "new_id"
        assert response.json()["message"] == "Book created"

def test_update_book():
    with patch('main.db') as mock_db:
        mock_doc_ref = MagicMock()
        mock_db.collection.return_value.document.return_value = mock_doc_ref
        
        response = client.put("/api/books/test_id", json={"name": "Updated Book", "hierarchy": []})
        assert response.status_code == 200
        assert response.json()["message"] == "Book updated"

def test_delete_book():
    with patch('main.db') as mock_db:
        mock_doc_ref = MagicMock()
        mock_db.collection.return_value.document.return_value = mock_doc_ref
        
        # Mock words stream for soft delete
        mock_word_doc = MagicMock()
        mock_db.collection.return_value.document.return_value.collection.return_value.stream.return_value = [mock_word_doc]
        
        response = client.delete("/api/books/test_id")
        assert response.status_code == 200
        assert response.json()["message"] == "Book and associated words soft deleted"

def test_ocr_extract():
    with patch('main.GenerativeModel') as mock_model_class:
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = '["word1", "word2"]'
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model
        
        # Mock file upload
        file_content = b"fake image content"
        response = client.post("/api/ocr", files={"file": ("test.jpg", file_content, "image/jpeg")})
        
        assert response.status_code == 200
        assert "words" in response.json()
        assert "word1" in response.json()["words"]

def test_get_word_details():
    with patch('main.GenerativeModel') as mock_model_class:
        mock_model = MagicMock()
        mock_response = MagicMock()
        mock_response.text = '{"word": "test", "meaning": "测试"}'
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model
        
        response = client.post("/api/word_details", json={"word": "test"})
        
        assert response.status_code == 200
        assert "details" in response.json()
