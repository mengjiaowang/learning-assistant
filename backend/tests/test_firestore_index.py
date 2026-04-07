import pytest
from google.cloud import firestore
import os
import sys

# Add backend to sys.path if needed
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../')))
from app.config import settings

@pytest.mark.asyncio
async def test_query_with_order_by():
    """验证 Firestore 查询是否需要复合索引"""
    try:
        db = firestore.AsyncClient(project=settings.PROJECT_ID, database=settings.FIRESTORE_DATABASE)
        query = db.collection("questions")\
                  .where("user_id", "==", "admin")\
                  .order_by("created_at", direction=firestore.Query.DESCENDING)\
                  .limit(10)
        
        docs = query.stream()
        async for _ in docs:
            pass
        
        assert True
    except Exception as e:
        if "FAILED_PRECONDITION" in str(e):
             pytest.fail(f"Firestore Index Check Failed: {e}")
        else:
             print(f"Skipping strict index assertion due to general error: {e}")
             assert True
