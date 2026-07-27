from sqlalchemy.orm import Session
import logging
import sys
from sqlalchemy import text
from fastapi import APIRouter, Body, HTTPException
from config import engine, SessionLocal
from point_record.model_point_record import create_point_record_model
import json

from utils_service.utils import model_to_dict

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()

@router.post(
      "/point_record/create_account"
      , summary="新增帳戶"
      , description="""新增帳戶, 參數
        { 'table_name': table_name
        , 'data': data,}""")   
def route_create_account(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    data = payload.get("data")
    db: Session = SessionLocal()
    try:
      PointRecordModel = create_point_record_model(table_name)
      query = db.query(PointRecordModel).filter(PointRecordModel.created_by == data["created_by"]).filter(PointRecordModel.account == data["account"]).filter(PointRecordModel.category == data["category"])
      account = query.first()
      if account:
        if account.is_valid != True:
          setattr(account, 'is_valid', True)
          db.commit()
        else:
          raise HTTPException(status_code=400, detail='Account already exists');
      else:
        data['points'] = 0
        data['is_valid'] = True
        account = PointRecordModel(**data)
        db.add(account)
        db.commit()
      return model_to_dict(account)
    finally:
      db.close()