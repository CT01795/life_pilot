import json

from config import engine
import pandas as pd
from sqlalchemy import text
from sklearn.ensemble import RandomForestClassifier
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

def prepare_stock_data(df: pd.DataFrame, is_train=True) -> pd.DataFrame:
    """
    計算未來一週漲幅百分比並產生 target (1=未來一週漲幅 >=10%, 0=其他)
    """
    df = df.sort_values(['security_code', 'date'])
    
    if is_train:
        # 計算未來5個交易日的最高收盤價
        df['future_price'] = df.groupby('security_code')['closing_price'].shift(-5)
        df['future_pct'] = (df['future_price'] - df['closing_price']) / df['closing_price'] * 100

    # === 2️⃣ 趨勢特徵（避免只看一天）===
    #df['pct_change_3d'] = df.groupby('security_code')['pct_change'].rolling(3).mean().reset_index(0, drop=True)
    df['pct_change_3d'] = df.groupby('security_code')['pct_change'].transform(lambda x: x.rolling(3).mean())
    #df['pct_change_5d'] = df.groupby('security_code')['pct_change'].rolling(5).mean().reset_index(0, drop=True)
    df['pct_change_5d'] = df.groupby('security_code')['pct_change'].transform(lambda x: x.rolling(5).mean())

    # 均線差（判斷多頭/空頭）
    df['ma_diff'] = df['ma5'] - df['ma20']

    # === 3️⃣ 避免模型被極端值帶歪 ===
    df['pct_change'] = df['pct_change'].clip(-7, 11)

    if is_train:
        # === 4️⃣ 移除不完整資料 ===
        df.dropna(subset=[
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff','future_pct'
        ], inplace=True)
    else:
        # === 4️⃣ 移除不完整資料 ===
        df.dropna(subset=[
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff'
        ], inplace=True)
    return df

def train_model():
    logging.info("train_model started")
    # 抓資料
    query = """
    SELECT security_code, date, ma5, ma20, high20, vol5, rsi, pct_change, closing_price,traded_number
    FROM stock_daily_price
    ORDER BY security_code, date
    """
    df = pd.read_sql(query, engine)
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
    # 儲存模型
    # joblib.dump(model, "stock_model.pkl")
    # logging.info("模型已儲存: stock_model.pkl")
    logging.info("train_model ended")
    return model

def train_and_save_model():
    try:
        logging.info("train_and_save_model started")
        model = train_model()
        logging.info("train_and_save_model model get")

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
        df = df[df['traded_number'] > 35000000]
        df = df[df['closing_price'] > 18]
        df['date'] = pd.to_datetime(df['date'], utc=True)
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
        BUY_THRESHOLD = 0.5

        df['signal'] = 0

        df.loc[
            (df['pred_pct'] >= BUY_THRESHOLD) &
            (df['ma5'] > df['ma20']), #&
            #(df['rsi'] < 75),
            'signal'
        ] = 1

        # ✅ 賣出訊號改用技術指標判斷，不依賴模型機率
        df.loc[df['rsi'] > 90, 'signal'] = -1

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
        df['date'] = pd.to_datetime(df['date'], utc=True)
        latest_date = df['date'].max()

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
        
        with engine.begin() as conn:
            conn.execute(
                text("""
                    INSERT INTO stock_predicted (date, data)
                    VALUES (:date, :data)
                    ON CONFLICT (date) DO UPDATE SET data = EXCLUDED.data
                """),
                {"date": latest_date.to_pydatetime(), "data": json.dumps(data_json)}
            )
            logging.info(f"✅ Saved prediction for {latest_date}")
            return data_json
    except Exception as e:
        logging.info(f"Error during training: {e}")
    finally:
        logging.info("train_and_save_model ended")
        
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
                    "stock_name": g.loc[i, 'security_name'],
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