from datetime import datetime
import json
from zoneinfo import ZoneInfo

import pandas as pd
from sqlalchemy import func, or_, text
from sqlalchemy.orm import Session
import logging
import sys
from fastapi import APIRouter, BackgroundTasks, Body
from config import engine, SessionLocal
from stock.model_stock_institutional import create_stock_institutional_model
from stock.model_futures_institutional import create_futures_institutional_model
from utils_service.utils import model_to_dict
from stock.train_model import train_and_save_model
from stock.model_stock_predicted import create_stock_predicted_model
from stock.model_stock import create_stock_model

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

router = APIRouter()
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
    print("route_delete_stock_daily_price DB_URL =", engine.url)
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
    print("route_delete_stock_date DB_URL =", engine.url)
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
def route_insert_stock_daily_price_batch(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    stocks_data = payload.get("stocks")
    db: Session = SessionLocal()
    print("route_insert_stock_daily_price_batch DB_URL =", engine.url)
    try:
      StockModel = create_stock_model(table_name)
      # 取得 model 欄位
      model_columns = StockModel.__table__.columns.keys()
      objects = []
      for stock_data in stocks_data:
        # 過濾不存在欄位
        filtered_data = {
            k: v
            for k, v in stock_data.items()
            if k in model_columns
        }
        # 處理 date
        if filtered_data.get("date"):
            filtered_data["date"] = (
                datetime.fromisoformat(
                    filtered_data["date"]
                ).astimezone(ZoneInfo("UTC"))
            )
        objects.append(
            StockModel(**filtered_data)
        )
      db.add_all(objects) 
      db.commit()
      return {"status": "ok"}
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
    print("route_insert_stock_institutional_batch DB_URL =", engine.url)
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
                SELECT *
                FROM futures_institutional
                WHERE date = :date
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
def route_insert_futures_institutional_batch(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    futures_institutional_data = payload.get("futures")
    db: Session = SessionLocal()
    print("route_insert_futures_institutional_batch DB_URL =", engine.url)
    try:
      FuturesInstitutionalModel = create_futures_institutional_model(table_name)
      # 取得 model 欄位
      model_columns = FuturesInstitutionalModel.__table__.columns.keys()
      objects = []
      for future_institutional_data in futures_institutional_data:
        # 過濾不存在欄位
        filtered_institutional_data = {
            k: v
            for k, v in future_institutional_data.items()
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
            FuturesInstitutionalModel(**filtered_institutional_data)
        )
      db.add_all(objects) 
      db.commit()
      return {"status": "ok"}
    except Exception as e:
      db.rollback()
      raise e
    finally:
      db.close()

@router.post(
      "/stock/insert_stock_date_batch"
      , summary="批量插入股票date"
      , description="""批量插入股票date, 參數
        { 'table_name': table_name
        , 'stocks': stocks,}""")   
def route_insert_stock_date_batch(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    stocks_data = payload.get("stocks")
    db: Session = SessionLocal()
    print("route_insert_stock_date_batch DB_URL =", engine.url)
    try:
      StockModel = create_stock_model(table_name)
      for stock_data in stocks_data:
            if stock_data.get("date"):
                stock_data["date"] = datetime.fromisoformat(
                    stock_data["date"].replace("Z", "+00:00")
                )
      objects = [
            StockModel(**stock_data)
            for stock_data in stocks_data
        ]
      db.add_all(objects) 
      db.commit()
      return {"status": "ok"}
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
    print("route_check_stock_date DB_URL =", engine.url)
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
    print("route_select_stock_daily_price_by_date DB_URL =", engine.url)
    try:
      StockModel = create_stock_model(table_name)
      result = db.query(StockModel).filter(func.date(StockModel.date) == date.date()).filter(StockModel.traded_number >= traded_number).filter(StockModel.closing_price >= 12).filter(StockModel.closing_price < 1000)
      stockList = result.all()
      if not stockList:
        return []
      return [model_to_dict(stock) for stock in stockList]
    finally:
      db.close()

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
    print("route_select_latest_stock_date DB_URL =", engine.url)
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
    print("route_select_stock_predicted DB_URL =", engine.url)
    try:
      print("select_stock_predicted")
      print(date)
      StockPredictedModel = create_stock_predicted_model(table_name)
      result = db.query(StockPredictedModel).filter(func.date(StockPredictedModel.date) == date.date())
      stockPredicted = result.first()
      if not stockPredicted:
        return {}
      return stockPredicted
    finally:
      db.close()

@router.post(
      "/stock/insert_stock_predicted"
      , summary="新增模型預測結果"
      , description="""新增模型預測結果, 參數
        { 'table_name': table_name
        , 'date': date}""")   
def route_insert_stock_predicted(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date").replace("Z", "+00:00"))
    stocks = payload.get("stocks")
    db: Session = SessionLocal()
    print("route_insert_stock_predicted DB_URL =", engine.url)
    try:
        StockPredictedModel = create_stock_predicted_model(table_name)
        row = StockPredictedModel(
            date=date,
            data=stocks,
            created_at=datetime.now()
        )
        db.add(row)
        db.commit()
        return {"status": "ok"}
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
    print("route_select_stock_quantitative_count DB_URL =", engine.url)
    print("date =", date)
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
    print("route_update_stock_technical_for_date DB_URL =", engine.url)
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
    logging.info("update_model started")
    background_tasks.add_task(train_and_save_model)
    return {"message": "Model training started in background"}

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