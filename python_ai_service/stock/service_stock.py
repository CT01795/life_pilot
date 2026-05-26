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
from utils_service.utils import model_to_dict
from stock.train_model import prepare_stock_data, backtest_model, train_and_save_model, train_model
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
def route_insert_stock_daily_price_batch(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    stocks_data = payload.get("stocks")
    db: Session = SessionLocal()
    try:
      StockModel = create_stock_model(table_name)
      for stock_data in stocks_data:
          if stock_data.get("date"):
              stock_data["date"] = datetime.fromisoformat(stock_data["date"]).astimezone(ZoneInfo("UTC"))
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
      "/stock/insert_stock_date_batch"
      , summary="批量插入股票date"
      , description="""批量插入股票date, 參數
        { 'table_name': table_name
        , 'stocks': stocks,}""")   
def route_insert_stock_date_batch(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    stocks_data = payload.get("stocks")
    db: Session = SessionLocal()
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
      "/stock/insert_stock_predicted"
      , summary="新增模型預測結果"
      , description="""新增模型預測結果, 參數
        { 'table_name': table_name
        , 'date': date}""")   
def route_insert_stock_predicted(payload: dict = Body(...)):
    table_name = payload.get("table_name")
    date = datetime.fromisoformat(payload.get("date").replace("Z", "+00:00"))
    stocks = payload.get("stocks")
    print("start")
    db: Session = SessionLocal()
    try:
        StockPredictedModel = create_stock_predicted_model(table_name)
        row = StockPredictedModel(
            date=date,
            data=stocks,
            created_at=datetime.now()
        )
        print(row)
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
    logging.info("update_model started")
    background_tasks.add_task(train_and_save_model)
    return {"message": "Model training started in background"}

@router.post(
      "/stock/backtest_model"
      , summary="模型回測"
      , description="模型回測")
def route_backtest_model():
    try:
        model = train_model()

        # 取得最新日期資料
        query = """
            SELECT *
            FROM stock_daily_price
            WHERE date >= (SELECT MAX(date) FROM stock_date WHERE type ='update_stock_technical_for_date') - INTERVAL '20 days'
            AND ma5 IS NOT NULL AND ma20 IS NOT NULL AND high20 IS NOT NULL
            AND vol5 IS NOT NULL AND rsi IS NOT NULL ORDER BY date desc;
        """
        df = pd.read_sql(query, engine)
        if df.empty:
            return {"stocks": [], "message": "No data available"}

        df = prepare_stock_data(df, is_train=False)

        # 👉 特徵
        features = [
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff'
        ]
    
        df = df.dropna(subset=features)
        logging.info("backtest_model started")
        trades = backtest_model(model, df, features)
        if trades.empty:
            return {"message": "No trades"}
        logging.info("backtest_model ended")

        insert_sql = text("""
            INSERT INTO stock_backtest (
                trade_date, stock_id, stock_name, entry_price, exit_price, buy_date, sell_date, return, holding_days
            ) VALUES (
                :trade_date, :stock_id, :stock_name, :entry_price, :exit_price, :buy_date, :sell_date, :return, :holding_days
            )
            ON CONFLICT (trade_date, stock_id) DO NOTHING
        """)

        batch_size = 1000

        for i in range(0, len(trades), batch_size):
            batch = trades.iloc[i:i+batch_size]
            with engine.begin() as conn:
                conn.execute(insert_sql, batch.to_dict(orient="records"))
    except Exception as e:
        return f"Error during Inserted: {i + len(batch)} rows"
    return "backtest_model OK"

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