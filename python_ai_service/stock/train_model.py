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
    df = df.sort_values(['security_code', 'date']).copy()
    
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

    # === 爆量 / 出貨特徵 ===
    df['vol_ratio'] = df['traded_number'] / df['vol5']

    df['price_drop_1d'] = df.groupby('security_code')['closing_price'].pct_change()

    df['distribution_flag'] = (
        (df['vol_ratio'] > 2) &
        (df['price_drop_1d'] < -0.03)
    ).astype(int)

    # === 3️⃣ 避免模型被極端值帶歪 ===
    df['pct_change'] = df['pct_change'].clip(-7, 11)

    if is_train:
        # === 4️⃣ 移除不完整資料 ===
        df.dropna(subset=[
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff','future_pct',
            'vol_ratio','price_drop_1d','distribution_flag'
        ], inplace=True)
    else:
        # === 4️⃣ 移除不完整資料 ===
        df.dropna(subset=[
            'ma5','ma20','high20','vol5','rsi','pct_change',
            'pct_change_3d','pct_change_5d','ma_diff',
            'vol_ratio','price_drop_1d','distribution_flag'
        ], inplace=True)
    return df

def train_sell_model():
    logging.info("train_sell_model started")
    df = pd.read_sql("""
        SELECT security_code, date, ma5, ma20, high20, vol5, rsi,
               pct_change, closing_price, traded_number
        FROM stock_daily_price
        ORDER BY date, security_code
    """, engine)

    df = prepare_stock_data(df, is_train=False)

    # === SELL label（重點）===
    df['vol_ratio'] = df['traded_number'] / df['vol5']
    df['price_drop_1d'] = df.groupby('security_code')['closing_price'].pct_change()

    df['future_return_3d'] = (
        df.groupby('security_code')['closing_price']
        .shift(-3) / df['closing_price'] - 1
    )
    df['sell_target'] = (
        (df['ma5'] < df['ma20']) |
        (df['rsi'] > 85) |
        ((df['vol_ratio'] > 2) & (df['price_drop_1d'] < -0.03))
    ).astype(int)

    features = [
        'ma5','ma20','high20','vol5','rsi',
        'pct_change','pct_change_3d','pct_change_5d','ma_diff',
        'vol_ratio','price_drop_1d','distribution_flag'
    ]

    df = df.dropna(subset=features + ['sell_target'])

    X = df[features]
    y = df['sell_target']

    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=10,
        min_samples_leaf=30,
        class_weight="balanced",
        n_jobs=-1
    )

    model.fit(X, y)
    logging.info("train_sell_model ended")
    return model

def train_model():
    logging.info("train_model started")
    # 抓資料
    query = """
    SELECT security_code, date, ma5, ma20, high20, vol5, rsi, pct_change, closing_price,traded_number
    FROM stock_daily_price
    ORDER BY date, security_code
    """
    df = pd.read_sql(query, engine)
    # 計算 target
    df = prepare_stock_data(df, is_train=True)
    df['date'] = pd.to_datetime(df['date'])
    df = df.sort_values('date').copy()
    # 訓練資料
    features = [
        'ma5','ma20','high20','vol5','rsi','pct_change',
        'pct_change_3d','pct_change_5d','ma_diff',
        'vol_ratio','price_drop_1d','distribution_flag'
    ]
    df = df.dropna(subset=features + ['future_pct'])
    df = df[df['pct_change'] > -9]
    # df = df[df['ma_diff'] > 0]
    df = df[df['traded_number'] > 8000000]
    df = df[df['closing_price'] > 10]
    df['target'] = ((df['future_pct'] > 3) & (df['distribution_flag'] == 0)).astype(int)
    #future_pct > 3%可能會漲 & distribution_flag = 1 爆量出貨 → 排除
    #df['target'] = ((df['future_pct'] > 3)).astype(int)
    # 1️⃣ 先排序
    df = df.sort_values('date').copy()

    # 2️⃣ 用「日期切分」（關鍵）
    unique_dates = df['date'].drop_duplicates().sort_values()

    split_index = int(len(unique_dates) * 0.8)
    split_date = unique_dates.iloc[split_index]

    train_df = df[df['date'] < split_date]
    test_df = df[df['date'] >= split_date]

    X_train = train_df[features]
    y_train = train_df['target']

    X_test = test_df[features]
    y_test = test_df['target']

    model = RandomForestClassifier(
        n_estimators=300,       # ✅ 增加樹的數量
        max_depth=10,            # ✅ 限制深度，避免過擬合
        min_samples_leaf=30,    # ✅ 每個葉子至少 30 筆，避免過擬合
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
        model2 = train_sell_model()
        logging.info("train_and_save_model model2 get")

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
            'pct_change_3d','pct_change_5d','ma_diff',
            'vol_ratio','price_drop_1d','distribution_flag'
        ]

        X = df[features]
        df['pred_class'] = model.predict(X)
        #df['pred_prob'] = model.predict_proba(X)[:, 1]
        df['buy_prob'] = model.predict_proba(X)[:, 1]
        df['sell_prob'] = model2.predict_proba(X)[:, 1]
        #df['pred_pct'] = df['pred_prob']
        df['buy_pct'] = df['buy_prob']
        df['sell_pct'] = df['sell_prob']
        # ===== 新增這段 =====
        BUY_THRESHOLD = 0.5
        SELL_THRESHOLD = 0.6

        df['signal'] = 0

        #df.loc[
        #    (df['pred_pct'] >= BUY_THRESHOLD) &
        #    (df['ma5'] > df['ma20']), #&
        #    #(df['rsi'] < 75),
        #    'signal'
        #] = 1
        # ===== BUY =====
        df.loc[
            (df['buy_pct'] >= BUY_THRESHOLD) &
            (df['ma5'] > df['ma20']) &
            (df['distribution_flag'] == 0),
            'signal'
        ] = 1

        # ===== SELL =====
        df.loc[
            (df['sell_pct'] >= SELL_THRESHOLD) |
            (df['rsi'] > 90) |
            (df['distribution_flag'] == 1),
            'signal'
        ] = -1
        # ✅ 賣出訊號改用技術指標判斷，不依賴模型機率
        #df.loc[df['rsi'] > 90, 'signal'] = -1

        df['signal_text'] = df['signal'].map({
            1: 'BUY',
            -1: 'SELL',
            0: 'HOLD'
        })

        df['score'] = df['buy_pct'] - df['sell_pct']
        buy_list = df[df['signal'] == 1] \
            .sort_values(by="score", ascending=False) \
            .head(50)
        buy_list['signal_text'] ='BUY'
        buy_list['signal'] = 1
        buy_list['pred_pct'] = buy_list['buy_pct']
        sell_list = df[df['signal'] == -1] \
            .sort_values(by="sell_pct", ascending=False) \
            .head(50)
        sell_list['signal_text'] ='SELL'
        sell_list['signal'] = -1
        sell_list['pred_pct'] = sell_list['sell_pct']
        recommended = pd.concat([buy_list, sell_list], ignore_index=True)
        #recommended = df[df['signal'] != 0] \
        #    .sort_values(by="pred_pct", ascending=False) \
        #    .head(100)[[
        #    'date','security_code','security_name','closing_price','traded_number','pe_ratio'
        #    ,'ma5','ma20','high20','vol5','rsi','pct_change','pred_pct','signal','signal_text'
        #]]

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