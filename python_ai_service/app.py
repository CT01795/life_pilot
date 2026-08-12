from datetime import datetime
import logging
import sys
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from event.service_event import router as service_event_router
from stock.service_stock import router as service_stock_router
app = FastAPI()

# --------------------
# 設定 CORS
# --------------------
origins = [
    "*"  # ⚠️ 開發用允許所有網域，正式部署建議只允許你的 Flutter App 網域
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],          # 允許 GET, POST, PUT, DELETE 等
    allow_headers=["*"],          # 允許自訂 Header
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)


@app.get("/health")
@app.head("/health")
def health():
    return {
        "status": "ok",
        "time": datetime.now().isoformat()
    }

@app.get("/", summary="根節點", description="根節點，相當於網址 http://127.0.0.1:8000/ 的畫面訊息")
def root():
    return {"message": "API is running"}

app.include_router(service_event_router)
app.include_router(service_stock_router)
