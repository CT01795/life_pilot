import os
import json
import logging
import sys

import pandas as pd
from fastapi import BackgroundTasks, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, text
from train_model import backtest_model, train_model
from utils import prepare_stock_data

app = FastAPI()

# --------------------
# 設定 CORS
# --------------------
origins = [
    "*"  # ⚠️ 開發用允許所有網域，正式部署建議只允許你的 Flutter App 網域
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,        # 允許的來源
    allow_credentials=True,
    allow_methods=["*"],          # 允許 GET, POST, PUT, DELETE 等
    allow_headers=["*"],          # 允許自訂 Header
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

# Supabase 資料庫連線字串
DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

@app.get("/", summary="根節點", description="根節點，相當於網址 http://127.0.0.1:8000/ 的畫面訊息")
def root():
    return {"message": "API is running"}

@app.get("/samples", summary="取得範例資料", description="回傳最新一筆資料")
def get_samples():
    query = """
    SELECT *
    FROM stock_daily_price
    ORDER BY date DESC
    LIMIT 1 ;
    """
    df = pd.read_sql(query, engine)
    return df.to_dict(orient="records")

@app.post("/train_and_save_model", summary="訓練模型", description="訓練模型相關參數")
def train_and_save_model():
    try:
        logging.info("train_and_save_model started")
        model = train_model()
        logging.info("train_and_save_model model get")
        # 3️⃣ 查看每棵樹
        logging.info(f"Number of trees: {len(model.estimators_)}")
        logging.info(model.estimators_[0])  # 第一棵決策樹的細節

        # 取得最新日期資料
        query = """
            SELECT *
            FROM stock_daily_price
            WHERE date >= (SELECT MAX(date) FROM stock_date WHERE type ='update_stock_technical_for_date') - INTERVAL '22 days'
            AND ma5 IS NOT NULL AND ma20 IS NOT NULL AND high20 IS NOT NULL
            AND vol5 IS NOT NULL AND rsi IS NOT NULL;
        """
        df = pd.read_sql(query, engine)
        if df.empty:
            return {"stocks": [], "message": "No data available"}

        df = prepare_stock_data(df, is_train=False)
        # ✅ 先做風險過濾（放這裡！！）
        #df = df[df['pct_change'] > -9]   # 避免暴跌股
        # df = df[df['ma_diff'] > 0]       # 避免空頭趨勢
        df = df[df['traded_number'] > 20000000]
        df = df[df['closing_price'] > 10]
        latest_date = df['date'].max()
        df = df[df['date'] == latest_date] # 取最新的一天

        # 👉 特徵
        features = [
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff'
        ]

        X = df[features]
        df['pred_class'] = model.predict(X)
        df['pred_prob'] = model.predict_proba(X)[:, 1]
        df['pred_pct'] = df['pred_prob']
        # ===== 新增這段 =====
        BUY_THRESHOLD = 0.35
        SELL_THRESHOLD = 0.15

        df['signal'] = 0

        df.loc[
            (df['pred_pct'] >= BUY_THRESHOLD) &
            (df['ma5'] > df['ma20']) &
            (df['rsi'] < 75),
            'signal'
        ] = 1

        df.loc[
            (df['pred_pct'] <= SELL_THRESHOLD) |
            (df['rsi'] > 88),
            'signal'
        ] = -1

        df['signal_text'] = df['signal'].map({
            1: 'BUY',
            -1: 'SELL',
            0: 'HOLD'
        })
        recommended = df[df['signal'] != 0] \
            .sort_values(by="pred_pct", ascending=False) \
            .head(100)[[
            'date','security_code','security_name','closing_price','traded_number','pe_ratio'
            ,'ma5','ma20','high20','vol5','rsi','pct_change','pred_pct','signal','signal_text'
        ]]

        recommended = recommended.fillna(0).replace([float('inf'), float('-inf')], 0)
        recommended['date'] = recommended['date'].astype(str)
        data_json = json.loads(recommended.to_json(orient="records", date_format="iso"))
        latest_date = df['date'].max()

        logging.info(recommended.shape)
        if recommended.empty:
            return {"message": "No recommended"}

        insert_sql = text("""
            INSERT INTO stock_predicted_list (
                date, security_code, security_name, closing_price, traded_number, pe_ratio, ma5, ma20
                , high20, vol5, rsi, pct_change, pred_pct, signal, signal_text
            ) VALUES (
                :date, :security_code, :security_name, :closing_price, :traded_number, :pe_ratio, :ma5, :ma20
                , :high20, :vol5, :rsi, :pct_change, :pred_pct, :signal, :signal_text
            )
            ON CONFLICT (date, security_code) DO NOTHING
        """)

        batch_size = 1000

        for i in range(0, len(recommended), batch_size):
            batch = recommended.iloc[i:i+batch_size]
            with engine.begin() as conn:
                conn.execute(insert_sql, batch.to_dict(orient="records"))
                logging.info(f"Inserted {i + len(batch)} rows")
        logging.info("Inserted OK")
        
        with engine.begin() as conn:
            conn.execute(
                text("""
                    INSERT INTO stock_predicted (date, data)
                    VALUES (:date, :data)
                    ON CONFLICT (date) DO UPDATE SET data = EXCLUDED.data
                """),
                {"date": str(latest_date), "data": json.dumps(data_json)}
            )
            logging.info(f"✅ Saved prediction for {latest_date}")
            return data_json
    except Exception as e:
        logging.info(f"Error during training: {e}")
    finally:
        logging.info("train_and_save_model ended")

@app.post("/update_model", summary="於背景訓練模型", description="於背景訓練模型相關參數")
def update_model(background_tasks: BackgroundTasks):
    logging.info("update_model started")
    background_tasks.add_task(train_and_save_model)
    return {"message": "Model training started in background"}

@app.get("/backtest_model", summary="回測", description="模型回測")
def backtest_model_api():
    try:
        logging.info("backtest_model_api train_model started")
        model = train_model()
        logging.info("backtest_model_api train_model get")
        # 3️⃣ 查看每棵樹
        logging.info(f"Number of trees: {len(model.estimators_)}")
        logging.info(model.estimators_[0])  # 第一棵決策樹的細節

        # 取得最新日期資料
        query = """
            SELECT *
            FROM stock_daily_price
            WHERE date >= (SELECT MAX(date) FROM stock_date WHERE type ='update_stock_technical_for_date') - INTERVAL '90 days'
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
        logging.info(df.shape)
        logging.info("backtest_model started")
        trades = backtest_model(model, df, features)
        logging.info(trades.shape)
        if trades.empty:
            return {"message": "No trades"}
        logging.info("backtest_model ended")

        insert_sql = text("""
            INSERT INTO stock_backtest (
                trade_date, stock_id, entry_price, exit_price, buy_date, sell_date, return, holding_days
            ) VALUES (
                :trade_date, :stock_id, :entry_price, :exit_price, :buy_date, :sell_date, :return, :holding_days
            )
            ON CONFLICT (trade_date, stock_id) DO NOTHING
        """)

        batch_size = 1000

        for i in range(0, len(trades), batch_size):
            batch = trades.iloc[i:i+batch_size]
            with engine.begin() as conn:
                conn.execute(insert_sql, batch.to_dict(orient="records"))
                logging.info(f"Inserted {i + len(batch)} rows")
    except Exception as e:
        logging.info(f"Error during Inserted: {i + len(batch)} rows")
        return f"Error during Inserted: {i + len(batch)} rows"
    logging.info("backtest_model OK")
    return "backtest_model OK"

@app.get("/predict", summary="取得預測資料", description="回傳預測資料")
def predict():
    # 先查 DB cache
    latest_date = pd.read_sql("SELECT MAX(date) as max_date FROM stock_predicted", engine)['max_date'].values[0]
    if latest_date is None:
        return {"stocks": [], "message": "No predictions yet, trigger /update_model first"}
    df_json = pd.read_sql(text("SELECT data FROM stock_predicted WHERE date=:date"), engine, params={"date": latest_date})
    if df_json.empty:
        return {"stocks": [], "message": "No predictions found"}
    data_json = json.loads(df_json.iloc[0]['data'])
    return data_json