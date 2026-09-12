#!/usr/bin/env python3
"""
错题年级历史数据迁移脚本
将数据库中所有缺少 'grade' 字段的错题统一更新为一年级 (grade=1)。
"""
import sys
import os
import argparse
import logging

# Ensure project path is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from google.cloud import firestore
from app.config import settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("migrate_grades")

def run_migration(target_grade: int = 1, force: bool = False, username: str = None):
    if target_grade < 1 or target_grade > 12:
        logger.error(f"Invalid target grade: {target_grade}. Must be between 1 and 12.")
        sys.exit(1)

    logger.info(f"Connecting to Firestore: project={settings.PROJECT_ID}, db={settings.MISTAKE_MENTOR_FIRESTORE_DB}...")
    db = firestore.Client(project=settings.PROJECT_ID, database=settings.MISTAKE_MENTOR_FIRESTORE_DB)
    
    questions_ref = db.collection("questions")
    if username:
        query = questions_ref.where("user_id", "==", username)
    else:
        query = questions_ref

    docs = query.stream(timeout=30)
    
    batch = db.batch()
    batch_count = 0
    total_updated = 0
    total_scanned = 0
    
    for doc in docs:
        total_scanned += 1
        data = doc.to_dict()
        
        # 仅在 force=True 或字段确实缺失时更新
        if force or ("grade" not in data):
            batch.update(doc.reference, {"grade": target_grade})
            batch_count += 1
            total_updated += 1
            logger.info(f"Queued question {doc.id} (user: {data.get('user_id')}) -> grade={target_grade}")
            
            if batch_count >= 400:
                batch.commit()
                logger.info(f"Committed batch of {batch_count} updates...")
                batch = db.batch()
                batch_count = 0
                
    if batch_count > 0:
        batch.commit()
        logger.info(f"Committed final batch of {batch_count} updates...")
        
    logger.info(f"Migration completed successfully. Total scanned: {total_scanned}, Total updated: {total_updated} to grade {target_grade}.")

def main():
    parser = argparse.ArgumentParser(description="Migrate questions in Firestore to have a valid grade.")
    parser.add_argument("--grade", type=int, default=1, help="Target grade (default: 1 for 一年级)")
    parser.add_argument("--force", action="store_true", help="Force update all questions even if grade is already set")
    parser.add_argument("--user", type=str, default=None, help="Filter by specific user_id")
    args = parser.parse_args()

    run_migration(target_grade=args.grade, force=args.force, username=args.user)

if __name__ == "__main__":
    main()
