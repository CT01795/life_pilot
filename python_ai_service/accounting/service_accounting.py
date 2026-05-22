from sqlalchemy.orm import Session
import logging
import sys
from sqlalchemy import text
from fastapi import APIRouter, Body, HTTPException
from config import engine, SessionLocal
from accounting.model_accounting_account import create_accounting_account_model
import json

from utils_service.utils import model_to_dict

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/accounting/find_account_by_id"
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
      AccountingAccountModel = create_accounting_account_model(table_name)
      query = db.query(AccountingAccountModel).filter(AccountingAccountModel.id == id).filter(AccountingAccountModel.created_by == user).filter(AccountingAccountModel.is_valid == True)
      account = query.first()
      if not account:
        raise HTTPException(status_code=404, detail="find_account_by_id account not found")
      return model_to_dict(account)
    finally:
      db.close()

@router.post(
      "/accounting/fetch_accounts"
      , summary="取得所有帳戶"
      , description="""取得所有帳戶, 參數
        { 'table_name':table_name
        , 'category': category
        , 'user': user}""")
def route_fetch_accounts(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    category = payload.get("category")
    user = payload.get("user")
    db: Session = SessionLocal()
    try:
      AccountingAccountModel = create_accounting_account_model(table_name)
      query = db.query(AccountingAccountModel).filter(AccountingAccountModel.category == category).filter(AccountingAccountModel.created_by == user).filter(AccountingAccountModel.is_valid == True).order_by(AccountingAccountModel.account)
      accountList = query.all()
      if not accountList:
        return []
      return [model_to_dict(account) for account in accountList]
    finally:
      db.close()

@router.post(
      "/accounting/create_account"
      , summary="新增帳戶"
      , description="""新增帳戶, 參數
        { 'table_name': table_name
        , 'data': data,}""")   
def route_create_account(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    data = payload.get("data")
    db: Session = SessionLocal()
    try:
      AccountingAccountModel = create_accounting_account_model(table_name)
      query = db.query(AccountingAccountModel).filter(AccountingAccountModel.created_by == data["created_by"]).filter(AccountingAccountModel.account == data["account"]).filter(AccountingAccountModel.category == data["category"])
      account = query.first()
      if account:
        if account.is_valid != True:
          setattr(account, 'is_valid', True)
          db.commit()
        else:
          raise HTTPException(status_code=400, detail='Account already exists');
      else:
        data['balance'] = 0
        data['exchange_rate'] = None
        data['is_valid'] = True
        account = AccountingAccountModel(**data)
        db.add(account)
        db.commit()
      return model_to_dict(account)
    finally:
      db.close()

@router.post(
      "/accounting/delete_account"
      , summary="刪除帳戶"
      , description="""刪除帳戶, 參數
        { 'table_name': table_name
        , 'id': id,}""")   
def route_delete_account(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    id = payload.get("id")
    db: Session = SessionLocal()
    try:
      AccountingAccountModel = create_accounting_account_model(table_name)
      query = db.query(AccountingAccountModel).filter(AccountingAccountModel.id == id)
      account = query.first()
      if account:
        if account.is_valid == True:
          setattr(account, 'is_valid', False)
          db.commit()
      else:
        raise HTTPException(status_code=404, detail="account not found")
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/accounting/upload_account_image_bytes_direct"
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
      AccountingAccountModel = create_accounting_account_model(table_name)
      query = db.query(AccountingAccountModel).filter(AccountingAccountModel.id == id)
      account = query.first()
      if account:
        if account.is_valid:
          setattr(account, 'master_graph_url', master_graph_url)
          db.commit()
      else:
        raise HTTPException(status_code=404, detail="account not found")
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/accounting/fetch_today_records"
      , summary="取得明細紀錄"
      , description="""取得明細紀錄, 參數
        { 'p_account_id': p_account_id
        , 'p_type': p_type,}""")     
def route_fetch_today_records(payload: dict = Body(...)):
    p_account_id = payload.get("p_account_id")
    p_type = payload.get("p_type")
    with engine.begin() as conn:
        result = conn.execute(
            text("SELECT row_to_json(t) FROM fetch_today_accountings(:p_account_id, :p_type) t"),
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
            output.append({"detail": {}, "balance": data["balance"]})
        else:
            output.append(data)

    return output

@router.post(
      "/accounting/insert_records_batch"
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
            text("SELECT add_accountings_batch2(:p_account_id, :p_type, :p_records)"),
            {
                "p_account_id": p_account_id,
                "p_type": p_type,
                "p_records": json.dumps(p_records),
            }
        )
    return {"status": "ok"}

@router.post(
      "/accounting/fetch_latest_account"
      , summary="取得最新主要幣別"
      , description="""取得最新主要幣別, 參數
        { 'table_name':table_name
        , 'category': category
        , 'user': user}""")
def route_fetch_latest_account(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    category = payload.get("category")
    user = payload.get("user")
    db: Session = SessionLocal()
    try:
      AccountingAccountModel = create_accounting_account_model(table_name)
      query = db.query(AccountingAccountModel).filter(AccountingAccountModel.category == category).filter(AccountingAccountModel.created_by == user).filter(AccountingAccountModel.is_valid == True).order_by(AccountingAccountModel.created_at.desc())
      account = query.first()
      if not account:
        return {"main_currency": "TWD",}
      return {"main_currency": account.main_currency,}
    finally:
      db.close()

@router.post(
      "/accounting/switch_main_currency"
      , summary="切換主要貨幣"
      , description="""切換主要貨幣, 參數
        { 'p_account_id': p_account_id
        , 'p_currency': p_currency,}""")     
def route_switch_main_currency(payload: dict = Body(...)):
    p_account_id = payload.get("p_account_id")
    p_currency = payload.get("p_currency")

    with engine.begin() as conn:
        conn.execute(
            text("SELECT switch_main_currency(:p_account_id, :p_currency)"),
            {
                "p_account_id": p_account_id,
                "p_currency": p_currency,
            }
        )
    return {"status": "ok"}

@router.post(
      "/accounting/update_accounting_detail"
      , summary="更新帳戶明細"
      , description="""更新帳戶明細, 參數
        { 'p_detail_id': p_detail_id
        , 'p_new_value': p_new_value
        , 'p_new_currency': p_new_currency
        , 'p_new_description': p_new_description,}""")     
def route_update_accounting_detail(payload: dict = Body(...)):
    p_detail_id = payload.get("p_detail_id")
    p_new_value = payload.get("p_new_value")
    p_new_currency = payload.get("p_new_currency")
    p_new_description = payload.get("p_new_description")

    with engine.begin() as conn:
        conn.execute(
            text("SELECT update_accounting_detail(:p_detail_id, :p_new_value, :p_new_currency, :p_new_description)"),
            {
                "p_detail_id": p_detail_id,
                "p_new_value": p_new_value,
                "p_new_currency": p_new_currency,
                "p_new_description": p_new_description,
            }
        )
    return {"status": "ok"}