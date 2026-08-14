from datetime import datetime
import logging
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from event.service_event import router as service_event_router
from external.service_external import router as service_external_router
from stock.service_stock import router as service_stock_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)


@app.get("/health")
@app.head("/health")
def health():
    return {
        "status": "ok",
        "time": datetime.now().isoformat(),
    }


@app.get("/", summary="Root endpoint")
def root():
    return {"message": "API is running"}


app.include_router(service_event_router)
app.include_router(service_external_router)
app.include_router(service_stock_router)
