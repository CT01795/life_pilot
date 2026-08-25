import json
import logging
import sys
from datetime import date as Date
from datetime import datetime, timedelta
from threading import Lock
from typing import Annotated, Any, Literal
from zoneinfo import ZoneInfo

import pandas as pd
from config import SessionLocal, engine
from fastapi import APIRouter, BackgroundTasks, Body, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, StringConstraints
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


class StockInstitutionalItem(BaseModel):
    model_config = ConfigDict(extra="allow")

    date: datetime
    stock_no: str = Field(min_length=1, max_length=20)


class StockInstitutionalBatchRequest(BaseModel):
    table_name: Literal["stock_institutional"]
    stocks: list[StockInstitutionalItem] = Field(
        min_length=1,
        max_length=10_000,
    )


class StockDailyPriceCleanupRequest(BaseModel):
    table_name: Literal["stock_daily_price"]
    date: datetime


class StockDateCleanupRequest(BaseModel):
    table_name: Literal["stock_date"]
    date: datetime


StockType = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=100),
]


class StockDateCheckRequest(BaseModel):
    table_name: Literal["stock_date"]
    date: datetime
    type: StockType


class LatestStockDateRequest(BaseModel):
    table_name: Literal["stock_date"]
    type: StockType


class StockDailyPriceQueryRequest(BaseModel):
    table_name: Literal["stock_daily_price"]
    date: datetime
    traded_number: float = Field(ge=0)


class StockPredictionQueryRequest(BaseModel):
    table_name: Literal["stock_predicted"]
    date: datetime


class StockPredictionInsertRequest(BaseModel):
    table_name: Literal["stock_predicted"]
    date: datetime
    data: list[dict[str, Any]] = Field(min_length=1, max_length=10_000)


class StockQuantitativeCountRequest(BaseModel):
    table_name: Literal["stock_daily_price"]
    date: datetime


class InstitutionalDateQueryRequest(BaseModel):
    date: Date


def _delete_stock_rows_before(*, table_name: str, cutoff: datetime) -> dict:
    latest_allowed_cutoff = (
        datetime.now(ZoneInfo("UTC")).date() - timedelta(days=30)
    )
    if cutoff.date() > latest_allowed_cutoff:
        raise HTTPException(
            status_code=422,
            detail="Stock cleanup cutoff must be at least 30 days old",
        )

    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      deleted_rows = (
          db.query(StockModel)
          .filter(StockModel.date <= cutoff.date())
          .delete(synchronize_session=False)
      )
      db.commit()
      return {
          "status": "ok",
          "deleted_rows": deleted_rows,
      }
    except SQLAlchemyError as exception:
      db.rollback()
      logger.exception("Could not clean up stock data")
      raise HTTPException(
          status_code=503,
          detail="Stock cleanup could not be completed",
      ) from exception
    finally:
      db.close()


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
def route_delete_stock_daily_price(payload: StockDailyPriceCleanupRequest):
    return _delete_stock_rows_before(
        table_name=payload.table_name,
        cutoff=payload.date,
    )

@router.post(
      "/stock/delete_stock_date"
      , summary="刪除指定日期的股票日期數據"
      , description="""刪除指定日期的股票日期數據, 參數
        { 'table_name': table_name
        , 'date': date,}""")   
def route_delete_stock_date(payload: StockDateCleanupRequest):
    return _delete_stock_rows_before(
        table_name=payload.table_name,
        cutoff=payload.date,
    )

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
def route_insert_stock_institutional_batch(
    payload: StockInstitutionalBatchRequest,
):
    stocks_institutional_data = [
        item.model_dump()
        for item in payload.stocks
    ]
    db: Session = SessionLocal()
    try:
      StockInstitutionalModel = create_stock_institutional_model(
          payload.table_name
      )
      # 取得 model 欄位
      model_columns = StockInstitutionalModel.__table__.columns.keys()
      filtered_stocks = [
        {
            k: v
            for k, v in item.items()
            if k in model_columns
        }
        for item in stocks_institutional_data
      ]
      stmt = insert(StockInstitutionalModel).values(filtered_stocks)
      stmt = stmt.on_conflict_do_nothing(
          index_elements=["date", "stock_no"]
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
      logger.exception("Could not insert stock institutional batch")
      raise HTTPException(
          status_code=503,
          detail="Stock institutional batch could not be saved",
      ) from exception
    finally:
      db.close()

@router.post("/stock/select_futures_institutional"
            , summary="查询三大法人futures數據"
            , description="""查询三大法人futures數據, 參數
              { 'date': date,}""")
def route_select_futures_institutional(
    payload: InstitutionalDateQueryRequest,
):
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
            {"date": payload.date}
        ).mappings().all()
        return [dict(row) for row in rows]
    except SQLAlchemyError as exception:
        logger.exception("Could not select futures institutional data")
        raise HTTPException(
            status_code=503,
            detail="Futures institutional data could not be loaded",
        ) from exception
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
def route_check_stock_date(payload: StockDateCheckRequest):
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(payload.table_name)
      existing_row = (
          db.query(StockModel.date)
          .filter(func.date(StockModel.date) == payload.date.date())
          .filter(StockModel.type == payload.type)
          .first()
      )
      return {"status": existing_row is not None}
    except SQLAlchemyError as exception:
      logger.exception("Could not check stock date")
      raise HTTPException(
          status_code=503,
          detail="Stock date could not be checked",
      ) from exception
    finally:
      db.close()

@router.post(
      "/stock/select_stock_daily_price_by_date"
      , summary="查詢股票每日價格"
      , description="""查詢股票每日價格數據, 參數
        { 'table_name': table_name
        , 'date': date
        , 'traded_number': traded_number}""")   
def route_select_stock_daily_price_by_date(
    payload: StockDailyPriceQueryRequest,
):
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(payload.table_name)
      stocks = (
          db.query(StockModel)
          .filter(func.date(StockModel.date) == payload.date.date())
          .filter(StockModel.traded_number >= payload.traded_number)
          .filter(StockModel.closing_price >= 12)
          .filter(StockModel.closing_price < 1000)
          .all()
      )
      if not stocks:
        return []
      return [model_to_dict(stock) for stock in stocks]
    except SQLAlchemyError as exception:
      logger.exception("Could not select stock daily prices")
      raise HTTPException(
          status_code=503,
          detail="Stock daily prices could not be loaded",
      ) from exception
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
def route_select_latest_stock_date(payload: LatestStockDateRequest):
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(payload.table_name)
      latest_stock_date = (
          db.query(StockModel.date)
          .filter(StockModel.type == payload.type)
          .order_by(StockModel.date.desc())
          .first()
      )
      if latest_stock_date is None:
        return {
          "date": None
        }
      return {
          "date": latest_stock_date[0]
      }
    except SQLAlchemyError as exception:
      logger.exception("Could not select latest stock date")
      raise HTTPException(
          status_code=503,
          detail="Latest stock date could not be loaded",
      ) from exception
    finally:
      db.close()

@router.post(
      "/stock/select_stock_predicted"
      , summary="查詢模型預測結果"
      , description="""查詢模型預測結果, 參數
        { 'table_name': table_name
        , 'date': date}""")   
def route_select_stock_predicted(payload: StockPredictionQueryRequest):
    db: Session = SessionLocal()
    try:
      StockPredictedModel = create_stock_predicted_model(payload.table_name)
      prediction = (
          db.query(StockPredictedModel)
          .filter(func.date(StockPredictedModel.date) == payload.date.date())
          .first()
      )
      if prediction is None:
        return {}
      return model_to_dict(prediction)
    except SQLAlchemyError as exception:
      logger.exception("Could not select stock prediction")
      raise HTTPException(
          status_code=503,
          detail="Stock prediction could not be loaded",
      ) from exception
    finally:
      db.close()

@router.post(
      "/stock/insert_stock_predicted"
      , summary="寫入模型預測結果"
      , description="由管理員後端寫入指定日期的模型預測結果")
def route_insert_stock_predicted(payload: StockPredictionInsertRequest):
    db: Session = SessionLocal()
    try:
      StockPredictedModel = create_stock_predicted_model(payload.table_name)
      stmt = insert(StockPredictedModel).values({
          "date": payload.date,
          "data": payload.data,
          "created_at": datetime.now(ZoneInfo("UTC")),
      })
      stmt = stmt.on_conflict_do_nothing(index_elements=["date"])

      result = db.execute(stmt)
      db.commit()
      inserted_rows = max(result.rowcount or 0, 0)
      return {
          "status": "ok",
          "inserted_rows": inserted_rows,
          "skipped_rows": 1 - inserted_rows,
      }
    except SQLAlchemyError as exception:
      db.rollback()
      logger.exception("Could not insert stock prediction")
      raise HTTPException(
          status_code=503,
          detail="Stock prediction could not be saved",
      ) from exception
    finally:
      db.close()

@router.post(
      "/stock/select_stock_quantitative_count"
      , summary="量化筆數"
      , description="""量化筆數, 參數
        { 'table_name': table_name
        , 'date': date}""")   
def route_select_stock_quantitative_count(
    payload: StockQuantitativeCountRequest,
):
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(payload.table_name)
      incomplete_count = (
          db.query(StockModel)
          .filter(func.date(StockModel.date) == payload.date.date())
          .filter(
              or_(
                  StockModel.ma5.is_(None),
                  StockModel.ma20.is_(None),
                  StockModel.high20.is_(None),
                  StockModel.vol5.is_(None),
                  StockModel.rsi.is_(None),
              )
          )
          .count()
      )
      return {"count": incomplete_count}
    except SQLAlchemyError as exception:
      logger.exception("Could not count incomplete stock indicators")
      raise HTTPException(
          status_code=503,
          detail="Stock indicator count could not be loaded",
      ) from exception
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
