import base64
import logging
import sys
from functools import lru_cache
from urllib.parse import urlsplit

from fastapi import APIRouter, Body, Depends, HTTPException
import requests
from fastapi.responses import JSONResponse
from sqlalchemy import MetaData, Table, text
from sqlalchemy.dialects.postgresql import insert as postgres_insert

from config import SessionLocal, engine
from security.supabase_auth import require_supabase_admin, require_supabase_user

# Only proxy the exact public endpoints used by the application.
ALLOWED_REQUEST_PATHS = {
    ("GET", "www.twse.com.tw"): {
        "/exchangeReport/MI_INDEX",
        "/rwd/zh/fund/T86",
    },
    ("GET", "www.tpex.org.tw"): {
        "/www/zh-tw/afterTrading/otc",
    },
    ("POST", "www.tpex.org.tw"): {
        "/www/zh-tw/insti/dailyTrade",
    },
    ("GET", "www.taifex.com.tw"): {
        "/cht/3/futContractsDateDown",
    },
    ("GET", "www.taiwan.net.tw"): {
        "/m1.aspx",
    },
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

router = APIRouter()

SYSTEM_EVENT_OWNER_EMAIL = "minavi@alumni.nccu.edu.tw"
MAX_PUBLIC_EVENT_IMPORT_ROWS = 200
PUBLIC_EVENT_SOURCE_HOSTS = {
    "strolltimes.com",
    "cloud.culture.tw",
    "www.accupass.com",
    "www.paperwindmill.com.tw",
    "event.moc.gov.tw",
    "www.taiwan.net.tw",
    "www.ntpc.gov.tw",
    "cultureexpress.taipei",
}


@lru_cache(maxsize=1)
def _recommended_events_table() -> Table:
    return Table(
        "recommended_events",
        MetaData(),
        schema="public",
        autoload_with=engine,
    )


@lru_cache(maxsize=1)
def _recommended_event_url_table() -> Table:
    return Table(
        "recommended_event_url",
        MetaData(),
        schema="public",
        autoload_with=engine,
    )


def _validated_public_event_source(source_url: object) -> str:
    if not isinstance(source_url, str) or not source_url.strip():
        raise HTTPException(status_code=400, detail="A valid source URL is required")
    try:
        parsed = urlsplit(source_url)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid source URL") from error
    if (
        parsed.scheme.lower() != "https"
        or parsed.hostname not in PUBLIC_EVENT_SOURCE_HOSTS
        or parsed.username is not None
        or parsed.password is not None
        or parsed.port not in {None, 443}
    ):
        raise HTTPException(status_code=403, detail="Event source is not allowed")
    return source_url


def _sanitize_public_event(event: object, source_url: str) -> dict:
    if not isinstance(event, dict):
        raise HTTPException(status_code=400, detail="Every event must be an object")
    sanitized = dict(event)
    if not str(sanitized.get("id", "")).strip():
        raise HTTPException(status_code=400, detail="Event id is required")
    if not str(sanitized.get("name", "")).strip():
        raise HTTPException(status_code=400, detail="Event name is required")
    if not sanitized.get("start_date"):
        raise HTTPException(status_code=400, detail="Event start date is required")
    sanitized["account"] = SYSTEM_EVENT_OWNER_EMAIL
    sanitized["is_approved"] = False
    sanitized["source"] = source_url
    sub_events = sanitized.get("sub_events")
    if isinstance(sub_events, list):
        sanitized["sub_events"] = [
            _sanitize_public_event(item, source_url) for item in sub_events
        ]
    return sanitized


def _insert_public_events(events: list[dict], source_url: str) -> int:
    event_table = _recommended_events_table()
    marker_table = _recommended_event_url_table()
    allowed_columns = {column.name for column in event_table.columns}
    rows = [
        {
            key: value
            for key, value in _sanitize_public_event(event, source_url).items()
            if key in allowed_columns
        }
        for event in events
    ]
    db = SessionLocal()
    try:
        result = db.execute(
            postgres_insert(event_table)
            .values(rows)
            .on_conflict_do_nothing()
        )
        db.execute(
            postgres_insert(marker_table)
            .values(
                master_url=source_url,
                start_date=text(
                    "date_trunc('day', now() at time zone 'Asia/Taipei') "
                    "at time zone 'Asia/Taipei'"
                ),
            )
            .on_conflict_do_nothing(
                index_elements=["master_url", "start_date"],
            )
        )
        db.commit()
        return max(result.rowcount or 0, 0)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _validate_request_target(url: object, method: object) -> tuple[str, str]:
    if not isinstance(url, str) or not url.strip():
        raise HTTPException(status_code=400, detail="A valid URL is required")
    if not isinstance(method, str):
        raise HTTPException(status_code=400, detail="A valid method is required")

    normalized_method = method.upper()
    if normalized_method not in {"GET", "POST"}:
        raise HTTPException(status_code=400, detail="Only GET and POST are allowed")

    try:
        parsed_url = urlsplit(url)
        port = parsed_url.port
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid URL") from error

    hostname = parsed_url.hostname
    if (
        parsed_url.scheme.lower() != "https"
        or hostname is None
        or parsed_url.username is not None
        or parsed_url.password is not None
        or port not in {None, 443}
    ):
        raise HTTPException(status_code=400, detail="Only valid HTTPS URLs are allowed")

    allowed_paths = ALLOWED_REQUEST_PATHS.get(
        (normalized_method, hostname.lower()),
    )
    if allowed_paths is None or parsed_url.path not in allowed_paths:
        raise HTTPException(status_code=403, detail="Request target is not allowed")

    return url, normalized_method


@router.post(
      "/event/get_url_data"
      , summary="代理取得URL資料"
      , description="""代理取得URL資料, 參數
        { 'url': url
        , 'method': method
        , 'data_type': data_type}""",
      dependencies=[Depends(require_supabase_admin)])
def get_url_data(payload: dict = Body(...)):
    return _get_url_data(payload)


@router.post(
    "/event/get_public_event_url_data",
    dependencies=[Depends(require_supabase_user)],
)
def get_public_event_url_data(payload: dict = Body(...)):
    url, method = _validate_request_target(
        payload.get("url"),
        payload.get("method", "GET"),
    )
    parsed_url = urlsplit(url)
    if method != "GET" or parsed_url.hostname != "www.taiwan.net.tw":
        raise HTTPException(status_code=403, detail="Request target is not allowed")
    return _get_url_data(payload)


@router.post(
    "/event/import_public_events",
    dependencies=[Depends(require_supabase_user)],
)
def import_public_events(payload: dict = Body(...)):
    source_url = _validated_public_event_source(payload.get("source_url"))
    events = payload.get("events")
    if not isinstance(events, list) or not events:
        raise HTTPException(status_code=400, detail="Events are required")
    if len(events) > MAX_PUBLIC_EVENT_IMPORT_ROWS:
        raise HTTPException(status_code=413, detail="Too many events in one batch")
    inserted_rows = _insert_public_events(events, source_url)
    return {"status": "ok", "inserted_rows": inserted_rows}


@router.get(
    "/event/public_events_updated_today",
    dependencies=[Depends(require_supabase_user)],
)
def public_events_updated_today():
    db = SessionLocal()
    try:
        updated = db.execute(
            text(
                """
                select exists (
                  select 1
                  from public.recommended_event_url
                  where (start_date at time zone 'Asia/Taipei')::date =
                        (now() at time zone 'Asia/Taipei')::date
                )
                """
            ),
        ).scalar()
        return {"updated": bool(updated)}
    finally:
        db.close()


def _get_url_data(payload: dict):
    url, method = _validate_request_target(
        payload.get("url"),
        payload.get("method", "GET"),
    )

    try:
        data_type = payload.get("data_type")
        form_data = payload.get("body", {})
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
            "Referer": url}
        if method.upper() == "POST":
            res = requests.post(
                url,data=form_data,timeout=(10, 60),headers=headers,
                allow_redirects=False,
            )
        else:
            res = requests.get(
                url,timeout=(10, 180),headers=headers,
                allow_redirects=False,
            )
        res.raise_for_status()
        # 🔥 自動處理 big5 / utf8
        res.encoding = res.encoding or "utf-8"

        # 🔥 audio / text 分流
        result_data = (
            base64.b64encode(res.content).decode()
            if data_type == "audio"
            else res.text
        )
        return JSONResponse(content={
            "status": "ok",
            "data": result_data
        })
    except Exception:
        logger.exception("External event request failed")
        return {
            "status": "error",
            "message": "External service request failed",
        }
