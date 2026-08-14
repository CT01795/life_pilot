import asyncio
import hashlib
import logging
import os
import unicodedata
from datetime import datetime, time as datetime_time, timedelta, timezone
from time import monotonic
from typing import Annotated, Any

import httpx
from external.repository_geocodes import (
    claim_geocode_refresh,
    get_geocode_cache,
    mark_geocode_failed,
    save_geocode_result,
)
from external.repository_weather import (
    get_weather_forecast_cache,
    save_weather_forecast_cache,
)
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from security.rate_limit import InMemoryRateLimiter
from security.supabase_auth import require_supabase_user
from sqlalchemy.exc import SQLAlchemyError


router = APIRouter(prefix="/external", tags=["external"])
logger = logging.getLogger(__name__)

OPEN_WEATHER_TIMEOUT_SECONDS = 10.0
GEOCODE_SUCCESS_TTL_DAYS = 180
GEOCODE_NOT_FOUND_TTL_DAYS = 7
WEATHER_CACHE_TTL_SECONDS = 15 * 60
WEATHER_CACHE_MAX_ENTRIES = 2_000


class GeocodeRequest(BaseModel):
    query: str = Field(min_length=1, max_length=200)


class GeocodeResponse(BaseModel):
    lat: float | None = None
    lng: float | None = None


class WeatherRequest(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class WeatherItem(BaseModel):
    date: datetime
    main: str
    description: str
    icon: str
    temp: float
    feels_like: float
    temp_min: float
    temp_max: float
    pressure: float
    sea_level: float
    grnd_level: float


class WeatherResponse(BaseModel):
    items: list[WeatherItem]


_geocode_rate_limiter = InMemoryRateLimiter(
    max_requests=30,
    window_seconds=5 * 60,
)
_weather_rate_limiter = InMemoryRateLimiter(
    max_requests=30,
    window_seconds=5 * 60,
)
_weather_global_rate_limiter = InMemoryRateLimiter(
    max_requests=300,
    window_seconds=5 * 60,
)
_weather_cache: dict[str, tuple[float, WeatherResponse]] = {}


def _weather_cache_key(lat: float, lng: float) -> str:
    coordinate_bucket = (
        f"{round(lat * 1_000)}:{round(lng * 1_000)}"
    )
    return hashlib.sha256(coordinate_bucket.encode("ascii")).hexdigest()


def _get_cached_weather(
    cache_key: str,
) -> WeatherResponse | None:
    cached = _weather_cache.get(cache_key)
    if cached is None:
        return None

    expires_at, response = cached
    if expires_at <= monotonic():
        _weather_cache.pop(cache_key, None)
        return None
    return response


def _save_weather_cache(
    cache_key: str,
    response: WeatherResponse,
    *,
    expires_at: datetime | None = None,
) -> None:
    now = monotonic()
    if len(_weather_cache) >= WEATHER_CACHE_MAX_ENTRIES:
        expired_keys = [
            key
            for key, (expires_at, _) in _weather_cache.items()
            if expires_at <= now
        ]
        for key in expired_keys:
            _weather_cache.pop(key, None)

    while len(_weather_cache) >= WEATHER_CACHE_MAX_ENTRIES:
        oldest_key = next(iter(_weather_cache))
        _weather_cache.pop(oldest_key, None)

    ttl_seconds = WEATHER_CACHE_TTL_SECONDS
    if expires_at is not None:
        normalized_expiry = expires_at
        if normalized_expiry.tzinfo is None:
            normalized_expiry = normalized_expiry.replace(tzinfo=timezone.utc)
        seconds_until_expiry = (
            normalized_expiry - datetime.now(timezone.utc)
        ).total_seconds()
        ttl_seconds = min(ttl_seconds, max(0, seconds_until_expiry))

    if ttl_seconds > 0:
        _weather_cache[cache_key] = (now + ttl_seconds, response)


def _weather_response_from_persistent_cache(
    cached: dict[str, Any] | None,
) -> WeatherResponse | None:
    if cached is None or not isinstance(cached.get("forecast"), list):
        return None

    try:
        items = [
            WeatherItem.model_validate(item)
            for item in cached["forecast"]
            if isinstance(item, dict)
        ]
    except (TypeError, ValueError):
        return None
    if len(items) != len(cached["forecast"]):
        return None
    return WeatherResponse(items=items)


def _next_location_midnight_utc(timezone_offset_seconds: int) -> datetime:
    location_timezone = timezone(
        timedelta(seconds=timezone_offset_seconds)
    )
    now_local = datetime.now(timezone.utc).astimezone(location_timezone)
    tomorrow = now_local.date() + timedelta(days=1)
    next_midnight = datetime.combine(
        tomorrow,
        datetime_time.min,
        tzinfo=location_timezone,
    )
    return next_midnight.astimezone(timezone.utc)


def _require_open_weather_api_key() -> str:
    api_key = os.getenv("OPEN_WEATHER_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Weather service is not configured",
        )
    return api_key


def _valid_cached_response(
    cached: dict[str, Any] | None,
) -> GeocodeResponse | None:
    if cached is None or cached.get("status") not in {"success", "not_found"}:
        return None

    expires_at = cached.get("expires_at")
    if not isinstance(expires_at, datetime):
        return None
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= datetime.now(timezone.utc):
        return None

    if cached["status"] == "not_found":
        return GeocodeResponse()

    lat = cached.get("lat")
    lng = cached.get("lng")
    if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
        return None
    return GeocodeResponse(lat=float(lat), lng=float(lng))


def _database_unavailable(exception: Exception) -> HTTPException:
    logger.error("Geocode database request failed: %s", type(exception).__name__)
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Geocode database is temporarily unavailable",
    )


async def _read_geocode_cache(query_hash: str) -> dict[str, Any] | None:
    try:
        return await asyncio.to_thread(get_geocode_cache, query_hash)
    except (RuntimeError, SQLAlchemyError) as exception:
        raise _database_unavailable(exception) from exception


async def _mark_geocode_failed_safely(cache_id: int, error_code: str) -> None:
    try:
        await asyncio.to_thread(
            mark_geocode_failed,
            cache_id=cache_id,
            error_code=error_code,
        )
    except (RuntimeError, SQLAlchemyError) as exception:
        logger.error("Could not mark geocode as failed: %s", type(exception).__name__)


@router.post("/geocode", response_model=GeocodeResponse)
async def geocode(
    payload: GeocodeRequest,
    user: Annotated[dict[str, Any], Depends(require_supabase_user)],
) -> GeocodeResponse:
    query = unicodedata.normalize("NFKC", " ".join(payload.query.split()))
    if not query:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Geocode query cannot be blank",
        )

    query_hash = hashlib.sha256(query.casefold().encode("utf-8")).hexdigest()
    cached_response = _valid_cached_response(
        await _read_geocode_cache(query_hash)
    )
    if cached_response is not None:
        return cached_response

    api_key = _require_open_weather_api_key()

    try:
        cache_id = await asyncio.to_thread(claim_geocode_refresh, query_hash)
    except (RuntimeError, SQLAlchemyError) as exception:
        raise _database_unavailable(exception) from exception

    if cache_id is None:
        for _ in range(5):
            await asyncio.sleep(0.2)
            cached_response = _valid_cached_response(
                await _read_geocode_cache(query_hash)
            )
            if cached_response is not None:
                return cached_response
        return GeocodeResponse()

    try:
        _geocode_rate_limiter.check(str(user["id"]))
    except HTTPException:
        await _mark_geocode_failed_safely(cache_id, "rate_limited")
        raise

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(OPEN_WEATHER_TIMEOUT_SECONDS, connect=5.0),
        ) as client:
            response = await client.get(
                "https://api.openweathermap.org/geo/1.0/direct",
                params={
                    "q": query,
                    "limit": 1,
                    "appid": api_key,
                },
            )
    except httpx.HTTPError as exception:
        await _mark_geocode_failed_safely(cache_id, "provider_unavailable")
        logger.warning(
            "OpenWeather geocode request failed: %s",
            type(exception).__name__,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Geocode provider is temporarily unavailable",
        ) from exception

    if response.status_code != status.HTTP_200_OK:
        await _mark_geocode_failed_safely(cache_id, "provider_rejected")
        logger.warning("OpenWeather geocode returned HTTP %s", response.status_code)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Geocode provider rejected the request",
        )

    try:
        data = response.json()
    except ValueError as exception:
        await _mark_geocode_failed_safely(cache_id, "invalid_provider_response")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Geocode provider returned an invalid response",
        ) from exception

    result = GeocodeResponse()
    if isinstance(data, list) and data and isinstance(data[0], dict):
        raw_lat = data[0].get("lat")
        raw_lng = data[0].get("lon")
        if isinstance(raw_lat, (int, float)) and isinstance(
            raw_lng,
            (int, float),
        ):
            lat = float(raw_lat)
            lng = float(raw_lng)
            if -90 <= lat <= 90 and -180 <= lng <= 180:
                result = GeocodeResponse(lat=lat, lng=lng)

    try:
        await asyncio.to_thread(
            save_geocode_result,
            cache_id=cache_id,
            lat=result.lat,
            lng=result.lng,
            ttl_days=(
                GEOCODE_SUCCESS_TTL_DAYS
                if result.lat is not None and result.lng is not None
                else GEOCODE_NOT_FOUND_TTL_DAYS
            ),
        )
    except (RuntimeError, SQLAlchemyError) as exception:
        await _mark_geocode_failed_safely(cache_id, "database_error")
        raise _database_unavailable(exception) from exception

    return result


@router.post("/weather", response_model=WeatherResponse)
async def weather_forecast(
    payload: WeatherRequest,
    user: Annotated[dict[str, Any], Depends(require_supabase_user)],
) -> WeatherResponse:
    _weather_rate_limiter.check(str(user["id"]))
    cache_key = _weather_cache_key(payload.lat, payload.lng)
    cached_response = _get_cached_weather(cache_key)
    if cached_response is not None:
        return cached_response

    persistent_cache: dict[str, Any] | None = None
    try:
        persistent_cache = await asyncio.to_thread(
            get_weather_forecast_cache,
            cache_key,
        )
    except (RuntimeError, SQLAlchemyError) as exception:
        logger.warning(
            "Weather cache read failed; using provider: %s",
            type(exception).__name__,
        )

    persistent_response = _weather_response_from_persistent_cache(
        persistent_cache
    )
    if persistent_response is not None and persistent_cache is not None:
        _save_weather_cache(
            cache_key,
            persistent_response,
            expires_at=persistent_cache.get("expires_at"),
        )
        return persistent_response

    api_key = _require_open_weather_api_key()
    _weather_global_rate_limiter.check("open_weather_forecast")

    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(OPEN_WEATHER_TIMEOUT_SECONDS, connect=5.0),
        ) as client:
            response = await client.get(
                "https://api.openweathermap.org/data/2.5/forecast",
                params={
                    "lat": payload.lat,
                    "lon": payload.lng,
                    "appid": api_key,
                    "units": "metric",
                },
            )
    except httpx.HTTPError as exception:
        logger.warning(
            "OpenWeather forecast request failed: %s",
            type(exception).__name__,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather provider is temporarily unavailable",
        ) from exception

    if response.status_code != status.HTTP_200_OK:
        logger.warning(
            "OpenWeather forecast returned HTTP %s",
            response.status_code,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather provider rejected the request",
        )

    try:
        data = response.json()
    except ValueError as exception:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather provider returned an invalid response",
        ) from exception

    raw_items = data.get("list") if isinstance(data, dict) else None
    if not isinstance(raw_items, list):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather provider returned an invalid forecast",
        )

    raw_city = data.get("city") if isinstance(data, dict) else None
    raw_timezone_offset = (
        raw_city.get("timezone") if isinstance(raw_city, dict) else None
    )
    if (
        not isinstance(raw_timezone_offset, int)
        or isinstance(raw_timezone_offset, bool)
        or not -64_800 <= raw_timezone_offset <= 64_800
    ):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather provider returned an invalid location timezone",
        )
    expires_at = _next_location_midnight_utc(raw_timezone_offset)

    items: list[WeatherItem] = []
    try:
        for raw_item in raw_items:
            weather = raw_item["weather"][0]
            main = raw_item["main"]
            pressure = float(main["pressure"])
            items.append(
                WeatherItem(
                    date=datetime.fromtimestamp(
                        int(raw_item["dt"]),
                        tz=timezone.utc,
                    ),
                    main=str(weather["main"]),
                    description=str(weather["description"]),
                    icon=str(weather["icon"]),
                    temp=float(main["temp"]),
                    feels_like=float(main["feels_like"]),
                    temp_min=float(main["temp_min"]),
                    temp_max=float(main["temp_max"]),
                    pressure=pressure,
                    sea_level=float(main.get("sea_level", pressure)),
                    grnd_level=float(main.get("grnd_level", pressure)),
                )
            )
    except (KeyError, IndexError, TypeError, ValueError) as exception:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Weather provider returned an invalid forecast item",
        ) from exception

    result = WeatherResponse(items=items)
    _save_weather_cache(cache_key, result, expires_at=expires_at)
    try:
        await asyncio.to_thread(
            save_weather_forecast_cache,
            cache_key=cache_key,
            forecast=[item.model_dump(mode="json") for item in result.items],
            expires_at=expires_at,
        )
    except (RuntimeError, SQLAlchemyError) as exception:
        logger.warning(
            "Weather cache write failed; returning provider result: %s",
            type(exception).__name__,
        )
    return result
