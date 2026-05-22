from datetime import datetime

from sqlalchemy.orm import Session
import logging
import sys
from fastapi import APIRouter, Body, HTTPException
from config import SessionLocal

from feedback.model_feedback import create_feedback_model
from utils_service.utils import model_to_dict

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/feedback/insert"
      , summary="插入反饋"
      , description="""插入新的反饋, 參數
        { 'table_name': tableName
        , 'feedback_data': feedback_data,}""")   
def route_insert(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    feedback_data = payload.get("feedback_data")
    db: Session = SessionLocal()
    try:
      FeedbackModel = create_feedback_model(table_name)
      feedback = FeedbackModel(**feedback_data)
      db.add(feedback)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/feedback/select"
      , summary="查詢反饋"
      , description="""查詢反饋, 參數
        {'table_name': tableName,}""")     
def route_select(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    db: Session = SessionLocal()
    try:
      FeedbackModel = create_feedback_model(table_name)
      query = db.query(FeedbackModel).order_by(FeedbackModel.is_ok, FeedbackModel.created_at)
      feedbackList = query.all()
      if not feedbackList:
        return []
      return [model_to_dict(feedback) for feedback in feedbackList]
    finally:
      db.close()

@router.post(
      "/feedback/update"
      , summary="更新反饋"
      , description="""更新反饋, 參數
        { 'table_name': table_name
        , 'update_data': update_data,}""")     
def route_update(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    update_data = payload.get("update_data")
    db: Session = SessionLocal()
    try:
      FeedbackModel = create_feedback_model(table_name)
      query = db.query(FeedbackModel).filter(FeedbackModel.id == update_data.get("id"))
      feedback = query.first()
      if not feedback:
          raise HTTPException(status_code=404, detail="feedback not found")
      # 更新欄位
      deal_at = update_data.get("deal_at")
      if deal_at:
        deal_at = datetime.fromisoformat(deal_at)
      setattr(feedback, 'is_ok', update_data.get("is_ok"))
      setattr(feedback, 'deal_by', update_data.get("deal_by"))
      setattr(feedback, 'deal_at', deal_at)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()