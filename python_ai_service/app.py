import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
from sqlalchemy import create_engine
import joblib

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

# Supabase 資料庫連線字串
DB_URL = "postgresql://postgres.ccktdpycnferbrjrdtkp:QN4uJPxHzWR64e2u@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres" 
#DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

# 載入訓練好的模型
model = joblib.load("stock_model.pkl")

@app.get("/")
def root():
    return {"message": "API is running"}


@app.get("/stocks")
def get_stocks():
    query = """
    SELECT *
    FROM stock_daily_price
    ORDER BY date DESC
    LIMIT 1 ;
    """
    
    df = pd.read_sql(query, engine)

    return df.to_dict(orient="records")


@app.get("/predict")
def predict():
    # 取得最新一天資料
    query = """
    SELECT *
    FROM stock_daily_price
    WHERE date = (SELECT MAX(date) FROM stock_date)
    AND ma5 IS NOT NULL AND ma20 IS NOT NULL AND high20 IS NOT NULL
    AND vol5 IS NOT NULL AND rsi IS NOT NULL;
    """
    df = pd.read_sql(query, engine)
    print(df.shape)
    if df.empty:
        return {"stocks": [], "message": "No data available"}

    features = ['ma5','ma20','high20','vol5','rsi','pct_change']
    X = df[features]

    # 做預測
    df['pred'] = model.predict(X)

    # 過濾未來可能漲 >=10% 的股票
    recommended = df[df['pred']==1][['date','security_code','security_name','closing_price','traded_number','pe_ratio','ma5','ma20','high20','vol5','rsi','pct_change']]

    recommended = recommended.fillna(0).replace([float('inf'), float('-inf')], 0)
    return recommended.to_dict(orient="records")