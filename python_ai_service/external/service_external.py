import asyncio
import hashlib
import logging
import os
from datetime import date, datetime, timedelta, timezone
from typing import Annotated, Any, Literal
from urllib.parse import quote

import httpx
from external.repository_holidays import (
    claim_daily_sync,
    fetch_holidays,
    mark_sync_failed,
    save_sync_result,
)
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from security.rate_limit import InMemoryRateLimiter
from security.supabase_auth import require_supabase_user
from sqlalchemy.exc import SQLAlchemyError

router = APIRouter(prefix="/external", tags=["external"])
logger = logging.getLogger(__name__)

GOOGLE_TIMEOUT_SECONDS = 10.0
MAX_HOLIDAY_RANGE_DAYS = 366

HolidayLanguage = Literal["zh", "en", "ja", "ko"]
HOLIDAY_CALENDARS: dict[HolidayLanguage, tuple[str, str]] = {
    "zh": ("TW", "zh.taiwan#holiday@group.v.calendar.google.com"),
    "en": ("US", "en.usa#holiday@group.v.calendar.google.com"),
    "ja": ("JP", "ja.japanese#holiday@group.v.calendar.google.com"),
    "ko": ("KR", "ko.south_korea#holiday@group.v.calendar.google.com"),
}


class HolidayRequest(BaseModel):
    start: datetime
    end: datetime
    language_code: HolidayLanguage


class HolidayItem(BaseModel):
    date: str
    summary: str


class HolidayResponse(BaseModel):
    items: list[HolidayItem]


_holiday_rate_limiter = InMemoryRateLimiter(
    max_requests=30,
    window_seconds=5 * 60,
)


def _require_google_api_key() -> str:
    google_api_key = os.getenv("GOOGLE_API_KEY", "").strip()
    if not google_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Holiday service is not configured",
        )
    return google_api_key


def _to_utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Holiday dates must include a timezone",
        )
    return value.astimezone(timezone.utc)


async def _fetch_google_holidays(
    *,
    language_code: HolidayLanguage,
    country_code: str,
    calendar_id: str,
    calendar_year: int,
) -> list[dict[str, Any]]:
    google_api_key = _require_google_api_key()
    calendar_path = quote(calendar_id, safe="")
    url = (
        "https://www.googleapis.com/calendar/v3/calendars/"
        f"{calendar_path}/events"
    )
    year_start = datetime(calendar_year, 1, 1, tzinfo=timezone.utc)
    year_end = datetime(calendar_year + 1, 1, 1, tzinfo=timezone.utc)

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(GOOGLE_TIMEOUT_SECONDS, connect=5.0),
        ) as client:
            response = await client.get(
                url,
                headers={"x-goog-api-key": google_api_key},
                params={
                    "timeMin": year_start.isoformat(),
                    "timeMax": year_end.isoformat(),
                    "orderBy": "startTime",
                    "singleEvents": "true",
                    "maxResults": 2500,
                },
            )
    except httpx.HTTPError as exception:
        logger.warning("Google Calendar request failed: %s", type(exception).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Holiday provider is temporarily unavailable",
        ) from exception

    if response.status_code != status.HTTP_200_OK:
        logger.warning("Google Calendar returned HTTP %s", response.status_code)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Holiday provider rejected the request",
        )

    try:
        response_data = response.json()
    except ValueError as exception:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Holiday provider returned an invalid response",
        ) from exception

    holidays: list[dict[str, Any]] = []
    raw_items = response_data.get("items", []) if isinstance(response_data, dict) else []
    if not isinstance(raw_items, list):
        return holidays

    for raw_item in raw_items:
        if not isinstance(raw_item, dict):
            continue

        raw_start = raw_item.get("start")
        raw_date = raw_start.get("date") if isinstance(raw_start, dict) else None
        raw_summary = raw_item.get("summary")
        if not isinstance(raw_date, str) or not isinstance(raw_summary, str):
            continue

        summary = raw_summary.strip()
        if not summary:
            continue

        try:
            holiday_date = date.fromisoformat(raw_date)
        except ValueError:
            continue

        source_event_id = raw_item.get("id")
        if not isinstance(source_event_id, str) or not source_event_id:
            fallback = f"{country_code}|{holiday_date.isoformat()}|{summary}"
            source_event_id = "generated_" + hashlib.sha256(
                fallback.encode("utf-8")
            ).hexdigest()

        holidays.append(
            {
                "source_event_id": source_event_id,
                "holiday_date": holiday_date,
                "summary": summary,
                "language_code": language_code,
            }
        )

    return holidays


async def _mark_sync_failed_safely(sync_run_id: int, error_code: str) -> None:
    try:
        await asyncio.to_thread(
            mark_sync_failed,
            sync_run_id=sync_run_id,
            error_code=error_code,
        )
    except (RuntimeError, SQLAlchemyError) as exception:
        logger.error("Could not mark holiday sync as failed: %s", type(exception).__name__)


def _database_unavailable(exception: Exception) -> HTTPException:
    logger.error("Holiday database request failed: %s", type(exception).__name__)
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Holiday database is temporarily unavailable",
    )


@router.post("/holidays", response_model=HolidayResponse)
async def get_holidays(
    payload: HolidayRequest,
    _user: Annotated[dict[str, Any], Depends(require_supabase_user)],
) -> HolidayResponse:
    _holiday_rate_limiter.check(str(_user["id"]))

    start = _to_utc(payload.start)
    end = _to_utc(payload.end)

    if end <= start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Holiday end date must be after start date",
        )

    if end - start > timedelta(days=MAX_HOLIDAY_RANGE_DAYS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Holiday range cannot exceed {MAX_HOLIDAY_RANGE_DAYS} days",
        )

    start_date = payload.start.date()
    end_date = payload.end.date()
    if end_date <= start_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Holiday range must include at least one calendar date",
        )

    country_code, calendar_id = HOLIDAY_CALENDARS[payload.language_code]
    last_date = end_date - timedelta(days=1)
    calendar_years = range(start_date.year, last_date.year + 1)
    sync_date = datetime.now(timezone.utc).date()
    sync_error: HTTPException | None = None

    for calendar_year in calendar_years:
        try:
            sync_run_id = await asyncio.to_thread(
                claim_daily_sync,
                country_code=country_code,
                calendar_year=calendar_year,
                sync_date=sync_date,
            )
        except (RuntimeError, SQLAlchemyError) as exception:
            raise _database_unavailable(exception) from exception

        if sync_run_id is None:
            continue

        try:
            holidays = await _fetch_google_holidays(
                language_code=payload.language_code,
                country_code=country_code,
                calendar_id=calendar_id,
                calendar_year=calendar_year,
            )
            await asyncio.to_thread(
                save_sync_result,
                sync_run_id=sync_run_id,
                country_code=country_code,
                language_code=payload.language_code,
                holidays=holidays,
            )
        except HTTPException as exception:
            await _mark_sync_failed_safely(sync_run_id, "google_provider_error")
            sync_error = exception
        except (RuntimeError, SQLAlchemyError) as exception:
            await _mark_sync_failed_safely(sync_run_id, "database_error")
            raise _database_unavailable(exception) from exception

    try:
        stored_holidays = await asyncio.to_thread(
            fetch_holidays,
            country_code=country_code,
            start_date=start_date,
            end_date=end_date,
        )
    except (RuntimeError, SQLAlchemyError) as exception:
        raise _database_unavailable(exception) from exception

    items = [
        HolidayItem(
            date=holiday["holiday_date"].isoformat(),
            summary=str(holiday["summary"]),
        )
        for holiday in stored_holidays
    ]
    if not items and sync_error is not None:
        raise sync_error

    return HolidayResponse(items=items)
