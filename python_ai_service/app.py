from datetime import datetime
import logging
import os
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from event.service_event import router as service_event_router
from external.service_external import router as service_external_router
from external.service_weather import router as service_weather_router
from stock.service_stock import router as service_stock_router

DEFAULT_CORS_ALLOWED_ORIGINS = (
    "https://ct01795.github.io",
    "https://life-pilot.onrender.com",
)
LOCAL_CORS_ORIGIN_REGEX = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"


def get_cors_allowed_origins() -> list[str]:
    configured_origins = os.getenv("CORS_ALLOWED_ORIGINS", "")
    if not configured_origins.strip():
        return list(DEFAULT_CORS_ALLOWED_ORIGINS)

    return [
        origin.strip().rstrip("/")
        for origin in configured_origins.split(",")
        if origin.strip()
    ]


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_cors_allowed_origins(),
    allow_origin_regex=LOCAL_CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logging.getLogger("httpx").setLevel(logging.WARNING)


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
app.include_router(service_weather_router)
app.include_router(service_stock_router)
