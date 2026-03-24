from fastapi import FastAPI
import pandas as pd
from sqlalchemy import create_engine

app = FastAPI()

# Supabase 資料庫連線字串
DB_URL = "postgresql://postgres.ccktdpycnferbrjrdtkp:QN4uJPxHzWR64e2u@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"

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