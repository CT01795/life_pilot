import pandas as pd

def prepare_stock_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    計算未來一週漲幅百分比並產生 target (1=未來一週漲幅 >=10%, 0=其他)
    """
    df = df.sort_values(['security_code', 'date'])
    # 計算未來5個交易日的最高收盤價
    df['future_max'] = df.groupby('security_code')['closing_price'].shift(-1).rolling(5).max()
    df['future_pct'] = (df['future_max'] - df['closing_price']) / df['closing_price'] * 100
    df['target'] = (df['future_pct'] >= 10).astype(int)
    # 移除缺失值
    df.dropna(subset=['ma5','ma20','high20','vol5','rsi','pct_change','target'], inplace=True)
    return df