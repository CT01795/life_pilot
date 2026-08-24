import base64
import logging
import sys
from uuid import UUID, uuid4
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
PUBLIC_EVENT_REFRESH_COMPLETE = "__life_pilot_public_event_refresh_complete__"
PUBLIC_EVENT_REFRESH_RUNNING_PREFIX = "__life_pilot_public_event_refresh_running__:"


def _refresh_marker_token(token: object) -> str:
    try:
        return str(UUID(str(token)))
    except (TypeError, ValueError, AttributeError) as error:
        raise HTTPException(status_code=400, detail="Invalid refresh token") from error


def _start_public_event_refresh() -> dict:
    db = SessionLocal()
    try:
        db.execute(text("select pg_advisory_xact_lock(hashtext('life_pilot_public_event_refresh'))"))
        completed = db.execute(
            text(
                """
                select exists (
                  select 1 from public.recommended_event_url
                  where master_url = :complete_marker
                    and (start_date at time zone 'Asia/Taipei')::date =
                        (now() at time zone 'Asia/Taipei')::date
                )
                """
            ),
            {"complete_marker": PUBLIC_EVENT_REFRESH_COMPLETE},
        ).scalar()
        if completed:
            db.commit()
            return {"acquired": False, "updated": True, "token": None}

        active_token = db.execute(
            text(
                """
                select substring(master_url from :token_start)
                from public.recommended_event_url
                where left(master_url, :prefix_length) = :running_prefix
                  and start_date >= now() - interval '15 minutes'
                order by start_date desc
                limit 1
                """
            ),
            {
                "token_start": len(PUBLIC_EVENT_REFRESH_RUNNING_PREFIX) + 1,
                "prefix_length": len(PUBLIC_EVENT_REFRESH_RUNNING_PREFIX),
                "running_prefix": PUBLIC_EVENT_REFRESH_RUNNING_PREFIX,
            },
        ).scalar()
        if active_token:
            db.commit()
            return {"acquired": False, "updated": False, "token": None}

        db.execute(
            text(
                "delete from public.recommended_event_url "
                "where left(master_url, :prefix_length) = :running_prefix"
            ),
            {
                "prefix_length": len(PUBLIC_EVENT_REFRESH_RUNNING_PREFIX),
                "running_prefix": PUBLIC_EVENT_REFRESH_RUNNING_PREFIX,
            },
        )
        token = str(uuid4())
        db.execute(
            text(
                "insert into public.recommended_event_url (master_url, start_date) "
                "values (:marker, now())"
            ),
            {"marker": f"{PUBLIC_EVENT_REFRESH_RUNNING_PREFIX}{token}"},
        )
        db.commit()
        return {"acquired": True, "updated": False, "token": token}
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _finish_public_event_refresh(token: object, *, completed: bool) -> None:
    normalized_token = _refresh_marker_token(token)
    marker = f"{PUBLIC_EVENT_REFRESH_RUNNING_PREFIX}{normalized_token}"
    db = SessionLocal()
    try:
        deleted = db.execute(
            text(
                "delete from public.recommended_event_url "
                "where master_url = :marker returning master_url"
            ),
            {"marker": marker},
        ).scalar()
        if not deleted:
            raise HTTPException(status_code=409, detail="Refresh token is no longer active")
        if completed:
            db.execute(
                text(
                    "insert into public.recommended_event_url (master_url, start_date) "
                    "values (:complete_marker, now()) "
                    "on conflict do nothing"
                ),
                {"complete_marker": PUBLIC_EVENT_REFRESH_COMPLETE},
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def _heartbeat_public_event_refresh(token: object) -> None:
    normalized_token = _refresh_marker_token(token)
    marker = f"{PUBLIC_EVENT_REFRESH_RUNNING_PREFIX}{normalized_token}"
    db = SessionLocal()
    try:
        updated = db.execute(
            text(
                "update public.recommended_event_url set start_date = now() "
                "where master_url = :marker returning master_url"
            ),
            {"marker": marker},
        ).scalar()
        if not updated:
            raise HTTPException(status_code=409, detail="Refresh token is no longer active")
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


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
                  where master_url = :complete_marker
                    and (start_date at time zone 'Asia/Taipei')::date =
                        (now() at time zone 'Asia/Taipei')::date
                )
                """
            ),
            {"complete_marker": PUBLIC_EVENT_REFRESH_COMPLETE},
        ).scalar()
        running = db.execute(
            text(
                """
                select exists (
                  select 1
                  from public.recommended_event_url
                  where left(master_url, :prefix_length) = :running_prefix
                    and start_date >= now() - interval '15 minutes'
                )
                """
            ),
            {
                "prefix_length": len(PUBLIC_EVENT_REFRESH_RUNNING_PREFIX),
                "running_prefix": PUBLIC_EVENT_REFRESH_RUNNING_PREFIX,
            },
        ).scalar()
        return {"updated": bool(updated), "running": bool(running)}
    finally:
        db.close()


@router.post(
    "/event/start_public_event_refresh",
    dependencies=[Depends(require_supabase_user)],
)
def start_public_event_refresh():
    return _start_public_event_refresh()


@router.post(
    "/event/complete_public_event_refresh",
    dependencies=[Depends(require_supabase_user)],
)
def complete_public_event_refresh(payload: dict = Body(...)):
    _finish_public_event_refresh(payload.get("token"), completed=True)
    return {"status": "ok"}


@router.post(
    "/event/abort_public_event_refresh",
    dependencies=[Depends(require_supabase_user)],
)
def abort_public_event_refresh(payload: dict = Body(...)):
    _finish_public_event_refresh(payload.get("token"), completed=False)
    return {"status": "ok"}


@router.post(
    "/event/heartbeat_public_event_refresh",
    dependencies=[Depends(require_supabase_user)],
)
def heartbeat_public_event_refresh(payload: dict = Body(...)):
    _heartbeat_public_event_refresh(payload.get("token"))
    return {"status": "ok"}


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
