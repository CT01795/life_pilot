import os
from fastapi import FastAPI, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
from sqlalchemy import create_engine, text
import json
from utils import prepare_stock_data
from train_model import train_model
import logging
import sys

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
DB_URL = "postgresql://postgres.ccktdpycnferbrjrdtkp:QN4uJPxHzWR64e2u@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres" #os.getenv("DB_URL")  # 從render環境變數取得
#DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
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
        df = df[df['pct_change'] > -5]   # 避免暴跌股
        df = df[df['ma_diff'] > 0]       # 避免空頭趨勢
        df = df[df['traded_number'] > 9000000]
        df = df[df['closing_price'] > 10]
        latest_date = df['date'].max()
        df = df[df['date'] == latest_date] # 取最新的一天

        # 👉 特徵
        features = [
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff'
        ]

        X = df[features]
        df['pred_pct'] = model.predict(X)
        recommended = df[df['pred_pct'] >= 3].sort_values(by="pred_pct", ascending=False).head(50)[[
            'date','security_code','security_name','closing_price','traded_number','pe_ratio'
            ,'ma5','ma20','high20','vol5','rsi','pct_change','pred_pct'
        ]]

        recommended = recommended.fillna(0).replace([float('inf'), float('-inf')], 0)
        recommended['date'] = recommended['date'].astype(str)
        data_json = recommended.to_dict(orient="records")
        latest_date = df['date'].max()
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