from datetime import datetime, timezone

from sqlalchemy.orm import Session
import logging
import sys
from sqlalchemy import or_
from fastapi import APIRouter, Body, HTTPException
from config import SessionLocal

from module.model_module import create_user_module_model

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
@router.post(
      "/module/load_modules_from_server"
      , summary="取得模組清單"
      , description="""取得模組清單, 參數
        { 'table_name': table_name
        , 'account': account}""")
def route_load_modules_from_server(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    account = payload.get("account")
    db: Session = SessionLocal()
    try:
      UserModuleModel = create_user_module_model(table_name)
      query = db.query(UserModuleModel).filter(UserModuleModel.account == account).filter(
        or_(
            UserModuleModel.stop_at.is_(None),
            UserModuleModel.stop_at > datetime.now(timezone.utc)
        )
      )
      modules = query.all()
      if not modules:
        raise HTTPException(status_code=404, detail="load_modules_from_server modules not found")
      return [module.module_key for module in modules]
    finally:
      db.close()