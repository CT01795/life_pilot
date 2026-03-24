import os
from fastapi import FastAPI
import pandas as pd
from sqlalchemy import create_engine

app = FastAPI()

# Supabase 資料庫連線字串
DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

@app.get("/")
def root():
    return {"message": "API is running"}

@app.get("/stocks")
def get_stocks():
    query = """
    SELECT security_code, date, closing_price
    FROM stock_daily_price
    ORDER BY date DESC
    LIMIT 10;
    """
    
    df = pd.read_sql(query, engine)

    return df.to_dict(orient="records")