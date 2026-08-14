import asyncio
import hashlib
import logging
import os
import unicodedata
from datetime import datetime, timezone
from typing import Annotated, Any

import httpx
from external.repository_geocodes import (
    claim_geocode_refresh,
    get_geocode_cache,
    mark_geocode_failed,
    save_geocode_result,
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


class GeocodeRequest(BaseModel):
    query: str = Field(min_length=1, max_length=200)


class GeocodeResponse(BaseModel):
    lat: float | None = None
    lng: float | None = None


_geocode_rate_limiter = InMemoryRateLimiter(
    max_requests=30,
    window_seconds=5 * 60,
)


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
