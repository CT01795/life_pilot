import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
from sqlalchemy import create_engine
import joblib

app = FastAPI()

# --------------------
# 設定 CORS
# --------------------
origins = [
    "*"  # ⚠️ 開發用允許所有網域，正式部署建議只允許你的 Flutter App 網域
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,        # 允許的來源
    allow_credentials=True,
    allow_methods=["*"],          # 允許 GET, POST, PUT, DELETE 等
    allow_headers=["*"],          # 允許自訂 Header
)

# Supabase 資料庫連線字串
DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

# 載入訓練好的模型
model = joblib.load("stock_model.pkl")

@app.get("/")
def root():
    return {"message": "API is running"}


@app.get("/stocks")
def get_stocks():
    query = """
    SELECT *
    FROM stock_daily_price
    ORDER BY date DESC
    LIMIT 1 ;
    """
    
    df = pd.read_sql(query, engine)

    return df.to_dict(orient="records")


@app.get("/predict")
def predict():
    # 2️⃣ 看模型基本資訊
    print(model)  # RandomForestClassifier(n_estimators=100, ...)

    # 3️⃣ 查看每棵樹
    print(f"Number of trees: {len(model.estimators_)}")
    print(model.estimators_[0])  # 第一棵決策樹的細節

    # 4️⃣ 查看特徵重要性
    features = ['ma5','ma20','high20','vol5','rsi','pctChange']
    importances = model.feature_importances_

    # 取得最新一天資料
    query = """
    SELECT *
    FROM stock_daily_price
    WHERE date = (SELECT MAX(date) FROM stock_date)
    AND ma5 IS NOT NULL AND ma20 IS NOT NULL AND high20 IS NOT NULL
    AND vol5 IS NOT NULL AND rsi IS NOT NULL;
    """
    df = pd.read_sql(query, engine)
    print(df.shape)
    # 4️⃣ 查看特徵重要性
    df_imp = pd.DataFrame({"feature": features, "importance": importances})
    df_imp = df_imp.sort_values(by="importance", ascending=False)
    print(df_imp)
    
    if df.empty:
        return {"stocks": [], "message": "No data available"}

    features = ['ma5','ma20','high20','vol5','rsi','pct_change']
    X = df[features]

    # 👉 預測「上漲機率」
    df['prob'] = model.predict_proba(X)[:, 1]

    # 👉 先過濾機率 >= 0.5
    filtered = df[df['prob'] >= 0.5]

    # 👉 過濾未來可能漲 >=10% 的股票，依機率排序，選前50名
    recommended = filtered.sort_values(by="prob", ascending=False).head(50)[[
        'date','security_code','security_name','closing_price','traded_number','pe_ratio'
        ,'ma5','ma20','high20','vol5','rsi','pct_change','prob'
    ]]

    recommended = recommended.fillna(0).replace([float('inf'), float('-inf')], 0)
    return recommended.to_dict(orient="records")