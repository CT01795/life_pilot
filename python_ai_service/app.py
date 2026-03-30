import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
from sqlalchemy import create_engine
import joblib
from train_model import train_model
from fastapi import BackgroundTasks
from supabase import create_client
import io

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

# Supabase Storage 設定
SUPABASE_URL = os.getenv("SUPABASE_URL") or "https://ccktdpycnferbrjrdtkp.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNja3RkcHljbmZlcmJyanJkdGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNTU0NTIsImV4cCI6MjA2ODgzMTQ1Mn0.jsuY3AvuhRlCwuGKmcq_hyj1ViLRX18kmQs5YYnFwR4"  #anonKey
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

MODEL_FILE = "stock_model.pkl"
BUCKET = "models"  # 先在 Supabase Storage 建立一個 bucket 名稱叫 models

# Supabase 資料庫連線字串
DB_URL = os.getenv("DB_URL")  # 從render環境變數取得
engine = create_engine(DB_URL)

# 載入訓練好的模型
model = None
#model = joblib.load("stock_model.pkl")

# 上傳模型到 Supabase Storage
def upload_model_to_supabase(model):
    buffer = io.BytesIO()
    joblib.dump(model, buffer)
    buffer.seek(0)
    supabase.storage.from_(BUCKET).upload(MODEL_FILE, buffer, {"upsert": True})
    print("模型已上傳到 Supabase Storage")

# 從 Supabase Storage 下載模型
def load_model_from_supabase():
    data = supabase.storage.from_(BUCKET).download(MODEL_FILE)
    buffer = io.BytesIO(data)
    model = joblib.load(buffer)
    return model

def get_model():
    global model
    if model is None:
        model = load_model_from_supabase()
    return model

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
    global model
    model = get_model()
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
    WHERE date = (SELECT MAX(date) FROM stock_date WHERE type ='update_stock_technical_for_date')
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

@app.post("/update_model")
def update_model(background_tasks: BackgroundTasks):
    background_tasks.add_task(train_and_save_model)
    return {"message": "Model training started in background"}

def train_and_save_model():
    global model
    try:
        model = train_model()  # 重新訓練
        upload_model_to_supabase(model)
        return {"message": "Model updated successfully"}
    except Exception as e:
        return {"message": "Model update failed", "error": str(e)}