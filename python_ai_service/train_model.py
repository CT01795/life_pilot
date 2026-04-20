import os
import pandas as pd
from sqlalchemy import create_engine
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
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
    # 訓練資料
    features = [
        'ma5','ma20','high20','vol5','rsi','pct_change',
        'pct_change_3d','pct_change_5d','ma_diff'
    ]
    df = df.dropna(subset=features + ['future_pct'])
    df = df[df['pct_change'] > -9]
    # df = df[df['ma_diff'] > 0]
    df = df[df['traded_number'] > 8000000]
    df = df[df['closing_price'] > 10]
    X = df[features]
    df['target'] = ((df['future_pct'] > 3) | (df['future_pct'] > df['future_pct'].quantile(0.8))).astype(int)
    y = df['target']
    #y = df['future_pct']   # 👈 改成回歸目標

    # 分訓練集/測試集
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1, shuffle=False)

    model = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        n_jobs=-1,
        class_weight="balanced"
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)

    logging.info(classification_report(y_test, y_pred))
    # 儲存模型
    # joblib.dump(model, "stock_model.pkl")
    # logging.info("模型已儲存: stock_model.pkl")
    logging.info("train_model ended")
    return model

def backtest_model(model, df, features):
    df = df.copy()

    df['pred_prob'] = model.predict_proba(df[features])[:, 1]

    BUY_THRESHOLD = 0.35

    df['signal'] = 0
    df.loc[df['pred_prob'] >= BUY_THRESHOLD, 'signal'] = 1

    df = df.sort_values(['security_code', 'date'])

    trades = []

    for stock, g in df.groupby('security_code'):
        g = g.reset_index(drop=True)

        for i in range(len(g) - 5):
            if g.loc[i, 'signal'] == 1:

                buy_price = g.loc[i, 'closing_price']
                sell_price = g.loc[i + 5, 'closing_price']

                ret = (sell_price - buy_price) / buy_price

                trades.append({
                    "trade_date": g.loc[i, 'date'],   # 或 sell_date，看你定義
                    "stock_id": stock,
                    "entry_price": buy_price,
                    "exit_price": sell_price,
                    "buy_date": str(g.loc[i, 'date']),
                    "sell_date": str(g.loc[i + 5, 'date']),
                    "return": ret,
                    "holding_days": 5
                })

    return pd.DataFrame(trades)