import base64
import logging
import re
import sys
from uuid import UUID, uuid4
from functools import lru_cache
from urllib.parse import urlsplit

from fastapi import APIRouter, Body, Depends, HTTPException
import requests
from fastapi.responses import JSONResponse
from sqlalchemy import MetaData, Table, select, text
from sqlalchemy.dialects.postgresql import insert as postgres_insert

from config import SessionLocal, engine
from security.rate_limit import InMemoryRateLimiter
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
RECOMMENDED_EVENT_CLEANUP_MARKER = "__life_pilot_recommended_event_cleanup__"
_event_cleanup_rate_limiter = InMemoryRateLimiter(
    max_requests=10,
    window_seconds=5 * 60,
)


def _cleanup_recommended_events_once_per_day() -> bool:
    db = SessionLocal()
    try:
        db.execute(
            text(
                "select pg_advisory_xact_lock("
                "hashtext('life_pilot_recommended_event_cleanup'))"
            )
        )
        already_cleaned = db.execute(
            text(
                """
                select exists (
                  select 1
                  from public.recommended_event_url
                  where master_url = :marker
                    and (start_date at time zone 'Asia/Taipei')::date =
                        (now() at time zone 'Asia/Taipei')::date
                )
                """
            ),
            {"marker": RECOMMENDED_EVENT_CLEANUP_MARKER},
        ).scalar()
        if already_cleaned:
            db.commit()
            return False

        db.execute(
            text(
                "select public.cleanup_recommended_events("
                "((now() at time zone 'Asia/Taipei')::date - 2)::date)"
            )
        )
        db.execute(
            text(
                "insert into public.recommended_event_url "
                "(master_url, start_date) values (:marker, now())"
            ),
            {"marker": RECOMMENDED_EVENT_CLEANUP_MARKER},
        )
        db.commit()
        return True
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


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


@lru_cache(maxsize=1)
def _recommended_events_deleted_table() -> Table:
    return Table(
        "recommended_events_deleted",
        MetaData(),
        schema="public",
        autoload_with=engine,
    )


def _normalize_event_city(value: object) -> str:
    cleaned = (
        str(value or "")
        .replace("\u200b", "")
        .strip()
        .replace("\u81fa", "\u53f0")
    )
    aliases = {
        "hsinchu city": "\u65b0\u7af9",
        "hs": "\u65b0\u7af9",
        "new taipei city": "\u65b0\u5317",
        "ne": "\u65b0\u5317",
        "taipei city": "\u53f0\u5317",
        "ta": "\u53f0\u5317",
        "\u4e2d\u58e2\u5340": "\u6843\u5712",
        "\u9f13\u5c71\u5340": "\u9ad8\u96c4",
    }
    return aliases.get(cleaned.lower(), cleaned[:2] if len(cleaned) > 2 else cleaned)


def _normalize_event_date(value: object) -> str:
    if value is None:
        return ""
    if hasattr(value, "date") and not isinstance(value, str):
        value = value.date()
    return str(value).strip()[:10]


def _normalize_event_time(value: object) -> str:
    if value is None:
        return ""
    if hasattr(value, "strftime"):
        return value.strftime("%H:%M")
    match = re.match(r"^\s*(\d{1,2}):(\d{2})", str(value))
    return f"{int(match.group(1)):02d}:{match.group(2)}" if match else ""


def _event_tombstone_keys(event: dict) -> set[tuple[str, ...]]:
    date = _normalize_event_date(event.get("start_date"))
    city = _normalize_event_city(event.get("city"))
    location = (
        str(event.get("location") or "")
        .replace("\u200b", "")
        .strip()
        .replace("\u81fa", "\u53f0")
    )
    time = _normalize_event_time(event.get("start_time"))
    keys = {
        (
            "name",
            re.sub(r"[\s_]+", "", str(event.get("name") or "")).lower(),
            date,
            time,
            city,
            location,
        ),
        ("id", str(event.get("id") or "").strip(), date, city, location),
    }
    master_url = str(event.get("master_url") or "").strip()
    if master_url:
        keys.add(("source", master_url, date, time, city, location))
    return keys


def _event_identity_without_time(event: dict) -> tuple[str, ...]:
    return (
        "name-without-time",
        re.sub(r"[\s_]+", "", str(event.get("name") or "")).lower(),
        _normalize_event_date(event.get("start_date")),
        _normalize_event_city(event.get("city")),
        str(event.get("location") or "")
        .replace("\u200b", "")
        .strip()
        .replace("\u81fa", "\u53f0"),
    )


def _exclude_deleted_public_events(
    events: list[dict], deleted_events: list[dict]
) -> list[dict]:
    deleted_keys = {
        key for deleted in deleted_events for key in _event_tombstone_keys(deleted)
    }
    deleted_without_time = {
        _event_identity_without_time(event) for event in deleted_events
    }
    return [
        event
        for event in events
        if _event_tombstone_keys(event).isdisjoint(deleted_keys)
        and (
            _normalize_event_time(event.get("start_time")) != ""
            or _event_identity_without_time(event) not in deleted_without_time
        )
    ]


def _exclude_existing_untimed_public_events(
    events: list[dict], existing_events: list[dict]
) -> list[dict]:
    known_without_time = {
        _event_identity_without_time(event) for event in existing_events
    }
    accepted: list[dict] = []
    for event in events:
        identity = _event_identity_without_time(event)
        if (
            _normalize_event_time(event.get("start_time")) == ""
            and identity in known_without_time
        ):
            continue
        accepted.append(event)
        known_without_time.add(identity)
    return accepted


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
    deleted_table = _recommended_events_deleted_table()
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
        deleted_rows = [
            dict(row)
            for row in db.execute(
                select(
                    deleted_table.c.id,
                    deleted_table.c.name,
                    deleted_table.c.master_url,
                    deleted_table.c.start_date,
                    deleted_table.c.start_time,
                    deleted_table.c.city,
                    deleted_table.c.location,
                )
            ).mappings()
        ]
        rows = _exclude_deleted_public_events(rows, deleted_rows)
        existing_rows = [
            dict(row)
            for row in db.execute(
                select(
                    event_table.c.name,
                    event_table.c.start_date,
                    event_table.c.start_time,
                    event_table.c.city,
                    event_table.c.location,
                )
            ).mappings()
        ]
        rows = _exclude_existing_untimed_public_events(rows, existing_rows)
        inserted_rows = 0
        if rows:
            result = db.execute(
                postgres_insert(event_table)
                .values(rows)
                .on_conflict_do_nothing()
            )
            inserted_rows = max(result.rowcount or 0, 0)
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
        return inserted_rows
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


@router.post("/event/cleanup_recommended_events")
def cleanup_recommended_events(user: dict = Depends(require_supabase_user)):
    _event_cleanup_rate_limiter.check(str(user["id"]))
    cleaned = _cleanup_recommended_events_once_per_day()
    return {"status": "ok", "cleaned": cleaned}


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
