import pandas as pd

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
    df['pct_change_3d'] = df.groupby('security_code')['pct_change'].rolling(3).mean().reset_index(0, drop=True)
    df['pct_change_5d'] = df.groupby('security_code')['pct_change'].rolling(5).mean().reset_index(0, drop=True)

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