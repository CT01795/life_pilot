import os
import pandas as pd
from sqlalchemy import create_engine
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
#import joblib
from utils import prepare_stock_data
import logging
import sys

# Supabase / Postgres
DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

def train_model():
    logging.info("train_model started")
    # 抓資料
    query = """
    SELECT security_code, date, ma5, ma20, high20, vol5, rsi, pct_change, closing_price,traded_number
    FROM stock_daily_price
    WHERE date >= DATE '2025-04-16'
    ORDER BY security_code, date
    """
    df = pd.read_sql(query, engine)
    logging.info(df.shape)
    # 計算 target
    df = prepare_stock_data(df, is_train=True)
    df = df[df['pct_change'] > -5]
    df = df[df['ma_diff'] > 0]
    df = df[df['traded_number'] > 9000000]
    df = df[df['closing_price'] > 10]
    # 訓練資料
    features = [
        'ma5','ma20','high20','vol5','rsi','pct_change',
        'pct_change_3d','pct_change_5d','ma_diff'
    ]
    X = df[features]
    y = df['future_pct']   # 👈 改成回歸目標

    # 分訓練集/測試集
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1, shuffle=False)

    model = RandomForestRegressor(
        n_estimators=50,
        random_state=42,
        n_jobs=-1
    )
    model.fit(X_train, y_train)

    score = model.score(X_test, y_test)
    logging.info(f"R2 score: {score}")

    # 儲存模型
    # joblib.dump(model, "stock_model.pkl")
    # logging.info("模型已儲存: stock_model.pkl")
    logging.info("train_model ended")
    return model