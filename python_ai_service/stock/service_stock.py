import json
import logging
import sys
from datetime import datetime
from threading import Lock
from typing import Literal
from zoneinfo import ZoneInfo

import pandas as pd
from config import SessionLocal, engine
from fastapi import APIRouter, BackgroundTasks, Body, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from security.supabase_auth import require_supabase_admin
from sqlalchemy import func, or_, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session
from stock.model_futures_institutional import \
    create_futures_institutional_model
from stock.model_stock import create_stock_model
from stock.model_stock_institutional import create_stock_institutional_model
from stock.model_stock_predicted import create_stock_predicted_model
from stock.train_model import train_and_save_model

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

router = APIRouter(dependencies=[Depends(require_supabase_admin)])
_model_training_lock = Lock()
_model_training_state_lock = Lock()
_model_training_state = {
    "status": "idle",
    "started_at": None,
    "finished_at": None,
}


class StockDateItem(BaseModel):
    type: str = Field(min_length=1, max_length=100)
    date: datetime


class StockDateBatchRequest(BaseModel):
    table_name: Literal["stock_date"]
    stocks: list[StockDateItem] = Field(min_length=1, max_length=10_000)


class StockDailyPriceItem(BaseModel):
    model_config = ConfigDict(extra="allow")

    security_code: str = Field(min_length=1, max_length=32)
    date: datetime


class StockDailyPriceBatchRequest(BaseModel):
    table_name: Literal["stock_daily_price"]
    stocks: list[StockDailyPriceItem] = Field(min_length=1, max_length=10_000)


class FuturesInstitutionalItem(BaseModel):
    model_config = ConfigDict(extra="allow")

    date: datetime
    product_name: str = Field(min_length=1, max_length=50)
    identity_type: str = Field(min_length=1, max_length=20)


class FuturesInstitutionalBatchRequest(BaseModel):
    table_name: Literal["futures_institutional"]
    futures: list[FuturesInstitutionalItem] = Field(
        min_length=1,
        max_length=10_000,
    )


def _utc_now_iso() -> str:
    return datetime.now(ZoneInfo("UTC")).isoformat()


def _set_model_training_state(
    status: str,
    *,
    started_at: str | None = None,
    finished_at: str | None = None,
):
    with _model_training_state_lock:
      _model_training_state.update({
          "status": status,
          "started_at": started_at,
          "finished_at": finished_at,
      })


def _get_model_training_state() -> dict:
    with _model_training_state_lock:
      return dict(_model_training_state)


def _run_model_training():
    try:
      train_and_save_model()
      current_state = _get_model_training_state()
      _set_model_training_state(
          "succeeded",
          started_at=current_state["started_at"],
          finished_at=_utc_now_iso(),
      )
    except Exception:
      current_state = _get_model_training_state()
      _set_model_training_state(
          "failed",
          started_at=current_state["started_at"],
          finished_at=_utc_now_iso(),
      )
      raise
    finally:
      _model_training_lock.release()


@router.post(
      "/stock/delete_stock_daily_price"
      , summary="刪除指定日期的股票每日價格數據"
      , description="""刪除指定日期的股票每日價格數據, 參數
        { 'table_name': table_name
        , 'date': date,}""")   
def route_delete_stock_daily_price(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date"))
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      db.query(StockModel).filter(StockModel.date <= date.date()).delete(synchronize_session=False)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/stock/delete_stock_date"
      , summary="刪除指定日期的股票日期數據"
      , description="""刪除指定日期的股票日期數據, 參數
        { 'table_name': table_name
        , 'date': date,}""")   
def route_delete_stock_date(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date"))
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      db.query(StockModel).filter(StockModel.date <= date.date()).delete(synchronize_session=False)
      db.commit()
      return {"status": "ok"}
    finally:
      db.close()

@router.post(
      "/stock/insert_stock_daily_price_batch"
      , summary="批量插入股票數據"
      , description="""批量插入股票數據, 參數
        { 'table_name': table_name
        , 'stocks': stocks,}""")   
def route_insert_stock_daily_price_batch(payload: StockDailyPriceBatchRequest):
    stocks_data = [stock.model_dump() for stock in payload.stocks]
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(payload.table_name)
      # 取得 model 欄位
      model_columns = StockModel.__table__.columns.keys()
      filtered_stocks = [
        {
            k: v
            for k, v in stock_data.items()
            if k in model_columns
        }
        for stock_data in stocks_data
      ]
      stmt = insert(StockModel).values(filtered_stocks)
      stmt = stmt.on_conflict_do_nothing(
          index_elements=["security_code", "date"]
      )

      result = db.execute(stmt)
      db.commit()

      inserted_rows = max(result.rowcount or 0, 0)
      return {
          "status": "ok",
          "received_rows": len(filtered_stocks),
          "inserted_rows": inserted_rows,
          "skipped_rows": len(filtered_stocks) - inserted_rows,
      }
    except SQLAlchemyError as exception:
      db.rollback()
      logger.exception("Could not insert stock daily price batch")
      raise HTTPException(
          status_code=503,
          detail="Stock daily price batch could not be saved",
      ) from exception
    finally:
      db.close()

@router.post("/stock/select_stock_institutional"
            , summary="查询三大法人股票數據"
            , description="""查询三大法人股票數據, 參數
              { 'date': date,}""")
def route_select_stock_institutional(payload: dict = Body(...)):
    date = datetime.strptime(
        payload.get("date"),
        "%Y-%m-%d"
    ).date()
    db: Session = SessionLocal()
    try:
        rows = db.execute(
            text("""
                SELECT *
                FROM get_stock_institutional_candidates(:date)
            """),
            {"date": date}
        ).mappings().all()
        return [dict(row) for row in rows]
    finally:
        db.close()

@router.post(
      "/stock/insert_stock_institutional_batch"
      , summary="批量插入TWSE三大法人股票數據"
      , description="""批量插入TWSE三大法人股票數據, 參數
        { 'table_name': table_name
        , 'stocks': stocks,}""")   
def route_insert_stock_institutional_batch(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    stocks_institutional_data = payload.get("stocks")
    db: Session = SessionLocal()
    try:
      StockInstitutionalModel = create_stock_institutional_model(table_name)
      # 取得 model 欄位
      model_columns = StockInstitutionalModel.__table__.columns.keys()
      objects = []
      for stock_institutional_data in stocks_institutional_data:
        # 過濾不存在欄位
        filtered_institutional_data = {
            k: v
            for k, v in stock_institutional_data.items()
            if k in model_columns
        }
        # 處理 date
        if filtered_institutional_data.get("date"):
            filtered_institutional_data["date"] = (
                datetime.fromisoformat(
                    filtered_institutional_data["date"].replace("Z", "+00:00")
                )
            )
        objects.append(
            StockInstitutionalModel(**filtered_institutional_data)
        )
      db.add_all(objects) 
      db.commit()
      return {"status": "ok"}
    except Exception as e:
      db.rollback()
      raise e
    finally:
      db.close()

@router.post("/stock/select_futures_institutional"
            , summary="查询三大法人futures數據"
            , description="""查询三大法人futures數據, 參數
              { 'date': date,}""")
def route_select_futures_institutional(payload: dict = Body(...)):
    date = datetime.strptime(
        payload.get("date"),
        "%Y-%m-%d"
    ).date()
    db: Session = SessionLocal()
    try:
        rows = db.execute(
            text("""
                select * from futures_institutional 
                where date = :date
                order by CASE product_name
                          WHEN '臺股期貨' THEN 1
                          WHEN '小型臺指期貨' THEN 2
                          WHEN '微型臺指期貨' THEN 3
                          WHEN '金融期貨' THEN 4
                          WHEN '小型金融期貨' THEN 5
                          WHEN '電子期貨' THEN 6
                          WHEN '小型電子期貨' THEN 7
                          WHEN '非金電期貨' THEN 8
                          ELSE 999
                        END,
                        identity_type
            """),
            {"date": date}
        ).mappings().all()
        return [dict(row) for row in rows]
    finally:
        db.close()

@router.post(
      "/stock/insert_futures_institutional_batch"
      , summary="批量插入三大法人futures數據"
      , description="""批量插入三大法人futures數據, 參數
        { 'table_name': table_name
        , 'futures': futures,}""")   
def route_insert_futures_institutional_batch(
    payload: FuturesInstitutionalBatchRequest,
):
    futures_institutional_data = [
        item.model_dump()
        for item in payload.futures
    ]
    db: Session = SessionLocal()
    try:
      FuturesInstitutionalModel = create_futures_institutional_model(
          payload.table_name
      )
      # 取得 model 欄位
      model_columns = FuturesInstitutionalModel.__table__.columns.keys()
      filtered_futures = [
        {
            k: v
            for k, v in item.items()
            if k in model_columns
        }
        for item in futures_institutional_data
      ]
      stmt = insert(FuturesInstitutionalModel).values(filtered_futures)
      stmt = stmt.on_conflict_do_nothing(
          index_elements=["date", "product_name", "identity_type"]
      )

      result = db.execute(stmt)
      db.commit()

      inserted_rows = max(result.rowcount or 0, 0)
      return {
          "status": "ok",
          "received_rows": len(filtered_futures),
          "inserted_rows": inserted_rows,
          "skipped_rows": len(filtered_futures) - inserted_rows,
      }
    except SQLAlchemyError as exception:
      db.rollback()
      logger.exception("Could not insert futures institutional batch")
      raise HTTPException(
          status_code=503,
          detail="Futures institutional batch could not be saved",
      ) from exception
    finally:
      db.close()

@router.post(
      "/stock/insert_stock_date_batch"
      , summary="批量插入股票date"
      , description="""批量插入股票date, 參數
        { 'table_name': table_name
        , 'stocks': stocks,}""")   
def route_insert_stock_date_batch(payload: StockDateBatchRequest):
    stocks_data = [stock.model_dump() for stock in payload.stocks]
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(payload.table_name)
      stmt = insert(StockModel).values(stocks_data)

      # type + date 重複時忽略
      stmt = stmt.on_conflict_do_nothing(
          index_elements=["type", "date"]
      )

      result = db.execute(stmt)
      db.commit()

      inserted_rows = max(result.rowcount or 0, 0)
      return {
          "status": "ok",
          "received_rows": len(stocks_data),
          "inserted_rows": inserted_rows,
          "skipped_rows": len(stocks_data) - inserted_rows,
      }
    except SQLAlchemyError as exception:
      db.rollback()
      raise HTTPException(
          status_code=503,
          detail="Stock date batch could not be saved",
      ) from exception
    finally:
      db.close()

@router.post(
      "/stock/check_stock_date"
      , summary="判斷是否有資料"
      , description="""判斷是否有資料, 參數
        { 'table_name': table_name
        , 'date': date
        , 'type': type}""")   
def route_check_stock_date(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date"))
    type = payload.get("type")
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      result = db.query(StockModel).filter(func.date(StockModel.date) == date.date()).filter(StockModel.type == type)
      return {"status": result.count() > 0}
    finally:
      db.close()

@router.post(
      "/stock/select_stock_daily_price_by_date"
      , summary="查詢股票每日價格"
      , description="""查詢股票每日價格數據, 參數
        { 'table_name': table_name
        , 'date': date
        , 'traded_number': traded_number}""")   
def route_select_stock_daily_price_by_date(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date"))
    traded_number = payload.get("traded_number")
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      result = db.query(StockModel).filter(func.date(StockModel.date) == date.date()).filter(StockModel.traded_number >= traded_number).filter(StockModel.closing_price >= 12).filter(StockModel.closing_price < 1000)
      stockList = result.all()
      if not stockList:
        return []
      return [model_to_dict(stock) for stock in stockList]
    finally:
      db.close()

def model_to_dict(obj):
    return {
        c.name: getattr(obj, c.name)
        for c in obj.__table__.columns
    }

@router.post(
      "/stock/select_latest_stock_date"
      , summary="查詢最新股票日期"
      , description="""查詢最新股票日期, 參數
        { 'table_name': table_name
        , 'type': type}""")   
def route_select_latest_stock_date(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    type = payload.get("type")
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      result = db.query(StockModel).filter(StockModel.type == type).order_by(StockModel.date.desc())
      stockList = result.all()
      if not stockList:
        return {
          "date": None
        }
      stock = stockList[0]
      return {
          "date": stock.date
      }
    finally:
      db.close()

@router.post(
      "/stock/select_stock_predicted"
      , summary="查詢模型預測結果"
      , description="""查詢模型預測結果, 參數
        { 'table_name': table_name
        , 'date': date}""")   
def route_select_stock_predicted(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date").replace("Z", "+00:00"))
    db: Session = SessionLocal()
    try:
      StockPredictedModel = create_stock_predicted_model(table_name)
      result = db.query(StockPredictedModel).filter(func.date(StockPredictedModel.date) == date.date())
      stockPredicted = result.first()
      if not stockPredicted:
        return {}
      return stockPredicted
    finally:
      db.close()

@router.post(
      "/stock/select_stock_quantitative_count"
      , summary="量化筆數"
      , description="""量化筆數, 參數
        { 'table_name': table_name
        , 'date': date}""")   
def route_select_stock_quantitative_count(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date"))
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      result = db.query(StockModel).filter(func.date(StockModel.date) == date.date()).filter(
                or_(
                    StockModel.ma5 == None,
                    StockModel.ma20 == None,
                    StockModel.high20 == None,
                    StockModel.vol5 == None,
                    StockModel.rsi == None,
                )
            )
      count = result.count()
      return {"count": count}
      
    finally:
      db.close()

@router.post(
      "/stock/update_stock_technical_for_date"
      , summary="更新計量資料"
      , description="""更新計量資料, 參數
        { 'p_date': p_date
        , 'p_start': p_start
        , 'p_end': p_end,}""")     
def route_update_stock_technical_for_date(payload: dict = Body(...)):
    p_date = datetime.fromisoformat(payload.get("p_date")).astimezone(ZoneInfo("UTC"))
    p_start = payload.get("p_start")
    p_end = payload.get("p_end")
    with engine.begin() as conn:
        conn.execute(
            text("SELECT update_stock_technical_for_date(:p_date, :p_start, :p_end)"),
            {
                "p_date": p_date,
                "p_start": p_start,
                "p_end": p_end,
            }
        )
    return {"status": "ok"}

@router.post(
      "/stock/update_model"
      , summary="於背景訓練模型"
      , description="於背景訓練模型")
def route_update_model(background_tasks: BackgroundTasks):
    if not _model_training_lock.acquire(blocking=False):
      raise HTTPException(
          status_code=409,
          detail="Model training is already in progress",
      )

    _set_model_training_state(
        "training",
        started_at=_utc_now_iso(),
        finished_at=None,
    )
    logging.info("update_model started")
    try:
      background_tasks.add_task(_run_model_training)
    except Exception:
      current_state = _get_model_training_state()
      _set_model_training_state(
          "failed",
          started_at=current_state["started_at"],
          finished_at=_utc_now_iso(),
      )
      _model_training_lock.release()
      raise
    return {"message": "Model training started in background"}


@router.get(
      "/stock/model_training_status"
      , summary="查詢模型訓練狀態"
      , description="查詢最近一次模型訓練的執行狀態")
def route_model_training_status():
    return _get_model_training_state()

@router.post(
      "/stock/backtest_model"
      , summary="模型回測"
      , description="模型回測")
def route_backtest_model():
    return {"stocks": [], "message": "No data available"}

@router.post(
      "/stock/predict"
      , summary="取得預測資料"
      , description="取得預測資料")
def route_predict():
    # 先查 DB cache
    latest_date = pd.read_sql("SELECT MAX(date) as max_date FROM stock_predicted", engine)['max_date'].values[0]
    if latest_date is None:
        return {"stocks": [], "message": "No predictions yet, trigger /update_model first"}
    df_json = pd.read_sql(text("SELECT data FROM stock_predicted WHERE date=:date"), engine, params={"date": latest_date})
    if df_json.empty:
        return {"stocks": [], "message": "No predictions found"}
    data_json = json.loads(df_json.iloc[0]['data'])
    return data_json
