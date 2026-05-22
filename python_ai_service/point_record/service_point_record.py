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
      "/point_record/find_account_by_id"
      , summary="查詢帳戶by id"
      , description="""查詢帳戶by id, 參數
        { 'table_name': table_name
        , 'id': id
        , 'user': user}""")     
def route_find_account_by_id(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    id = payload.get("id")
    user = payload.get("user")
    db: Session = SessionLocal()
    try:
      PointRecordModel = create_point_record_model(table_name)
      query = db.query(PointRecordModel).filter(PointRecordModel.id == id).filter(PointRecordModel.created_by == user).filter(PointRecordModel.is_valid == True)
      pointRecord = query.first()
      if not pointRecord:
        raise HTTPException(status_code=404, detail="find_account_by_id account not found")
      return model_to_dict(pointRecord)
    finally:
      db.close()

@router.post(
      "/point_record/fetch_accounts"
      , summary="取得所有帳戶"
      , description="""取得所有帳戶, 參數
        { 'table_name': table_name
        , 'category': category
        , 'user': user}""")     
def route_fetch_accounts(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    category = payload.get("category")
    user = payload.get("user")
    db: Session = SessionLocal()
    try:
      PointRecordModel = create_point_record_model(table_name)
      query = db.query(PointRecordModel).filter(PointRecordModel.created_by == user).filter(PointRecordModel.category == category).filter(PointRecordModel.is_valid == True).order_by(PointRecordModel.account)
      pointRecordList = query.all()
      if not pointRecordList:
        return []
      return [model_to_dict(pointRecord) for pointRecord in pointRecordList] 
    finally:
      db.close()

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

@router.post(
      "/point_record/delete_account"
      , summary="刪除帳戶"
      , description="""刪除帳戶, 參數
        { 'table_name': table_name
        , 'id': id,}""")   
def route_delete_account(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    id = payload.get("id")
    db: Session = SessionLocal()
    try:
      PointRecordModel = create_point_record_model(table_name)
      query = db.query(PointRecordModel).filter(PointRecordModel.id == id)
      pointRecord = query.first()
      if pointRecord:
        if pointRecord.is_valid == True:
          setattr(pointRecord, 'is_valid', False)
          db.commit()
      else:
        raise HTTPException(status_code=404, detail="account not found")
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/point_record/upload_account_image_bytes_direct"
      , summary="上傳帳戶圖片位元組"
      , description="""上傳帳戶圖片位元組, 參數
        { 'table_name': table_name
        , 'id': id
        , 'master_graph_url': master_graph_url,}""")   
def route_upload_account_image_bytes_direct(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    id = payload.get("id")
    master_graph_url = payload.get("master_graph_url")
    db: Session = SessionLocal()
    try:
      PointRecordModel = create_point_record_model(table_name)
      query = db.query(PointRecordModel).filter(PointRecordModel.id == id)
      pointRecord = query.first()
      if pointRecord:
        if pointRecord.is_valid:
          setattr(pointRecord, 'master_graph_url', master_graph_url)
          db.commit()
      else:
        raise HTTPException(status_code=404, detail="account not found")
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/point_record/fetch_today_records"
      , summary="取得明細紀錄"
      , description="""取得明細紀錄, 參數
        { 'p_account_id': p_account_id
        , 'p_type': p_type,}""")     
def route_fetch_today_records(payload: dict = Body(...)):
    p_account_id = payload.get("p_account_id")
    p_type = payload.get("p_type")
    with engine.begin() as conn:
        result = conn.execute(
            text("SELECT row_to_json(t) FROM fetch_today_point_records(:p_account_id, :p_type) t"),
            {
                "p_account_id": p_account_id,
                "p_type": p_type
            }
        )
    rows = result.fetchall()

    output = []
    for r in rows:
        data = r[0]  # 🔥 關鍵
        if data["detail"] is None:
            output.append({"detail": {}, "points": data["points"]})
        else:
            output.append(data)

    return output

@router.post(
      "/point_record/insert_records_batch"
      , summary="批量插入記錄"
      , description="""批量插入記錄, 參數
        { 'p_account_id': p_account_id
        , 'p_type': p_type
        , 'p_records': p_records,}""")     
def route_insert_records_batch(payload: dict = Body(...)):
    p_account_id = payload.get("p_account_id")
    p_type = payload.get("p_type")
    p_records = payload.get("p_records")

    with engine.begin() as conn:
        conn.execute(
            text("SELECT add_point_records_batch(:p_account_id, :p_type, :p_records)"),
            {
                "p_account_id": p_account_id,
                "p_type": p_type,
                "p_records": json.dumps(p_records),
            }
        )
    return {"status": "ok"}