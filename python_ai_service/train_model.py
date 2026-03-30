import os
import pandas as pd
from sqlalchemy import create_engine
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
#import joblib
from utils import prepare_stock_data

# Supabase / Postgres
DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

def train_model():
    # 抓資料
    query = """
    SELECT security_code, date, ma5, ma20, high20, vol5, rsi, pct_change, closing_price
    FROM stock_daily_price
    WHERE date >= DATE '2025-04-16'
    ORDER BY security_code, date
    """
    df = pd.read_sql(query, engine)
    print(df.shape)
    # 計算 target
    df = prepare_stock_data(df)

    # 訓練資料
    features = ['ma5','ma20','high20','vol5','rsi','pct_change']
    X = df[features]
    y = df['target']

    # 分訓練集/測試集
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1, shuffle=False)

    # 訓練 Random Forest
    model = RandomForestClassifier(n_estimators=50, random_state=42, class_weight="balanced")
    model.fit(X_train, y_train)

    # 測試效果
    y_pred = model.predict(X_test)
    print(classification_report(y_test, y_pred))

    # 儲存模型
    # joblib.dump(model, "stock_model.pkl")
    # print("模型已儲存: stock_model.pkl")

    return model