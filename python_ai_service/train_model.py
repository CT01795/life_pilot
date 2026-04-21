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
    df['target'] = ((df['future_pct'] > 3)).astype(int)
    X = df[features]
    y = df['target']

    # ✅ Walk-Forward: 用前 80% 訓練，後 20% 測試，保留時間順序
    split = int(len(df) * 0.8)
    X_train, X_test = X.iloc[:split], X.iloc[split:]
    y_train, y_test = y.iloc[:split], y.iloc[split:]

    model = RandomForestClassifier(
        n_estimators=200,       # ✅ 增加樹的數量
        max_depth=8,            # ✅ 限制深度，避免過擬合
        min_samples_leaf=50,    # ✅ 每個葉子至少 50 筆，避免過擬合
        random_state=42,
        n_jobs=-1,
        class_weight="balanced"
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    y_prob = model.predict_proba(X_test)[:, 1]
    logging.info(classification_report(y_test, y_pred))
    # 儲存模型
    # joblib.dump(model, "stock_model.pkl")
    # logging.info("模型已儲存: stock_model.pkl")
    logging.info("train_model ended")
    return model

def backtest_model(model, df, features):
    df = df.copy()

    COST = 0.003        # ✅ 單邊 0.3% 交易成本（含稅券商）
    BUY_THRESHOLD = 0.35

    df['pred_prob'] = model.predict_proba(df[features])[:, 1]
    df['signal'] = (df['pred_prob'] >= BUY_THRESHOLD).astype(int)
    df = df.sort_values(['security_code', 'date'])

    trades = []

    for stock, g in df.groupby('security_code'):
        g = g.reset_index(drop=True)
        in_position = False     # ✅ 避免重複買入同一檔
        for i in range(len(g) - 5):
            if g.loc[i, 'signal'] == 1 and not in_position:

                buy_price = g.loc[i, 'closing_price']
                sell_price = g.loc[i + 5, 'closing_price']

                # ✅ 扣除交易成本
                ret = (sell_price / buy_price) - 1 - COST * 2

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
                in_position = True
            elif in_position and i % 5 == 0:
                in_position = False     # ✅ 持倉 5 天後解鎖
    trades_df = pd.DataFrame(trades)
    if not trades_df.empty:
        # ✅ 印出基本回測統計
        logging.info(f"總交易次數: {len(trades_df)}")
        logging.info(f"勝率: {(trades_df['return'] > 0).mean():.2%}")
        logging.info(f"平均報酬: {trades_df['return'].mean():.2%}")
        logging.info(f"最大虧損: {trades_df['return'].min():.2%}")

    return trades_df