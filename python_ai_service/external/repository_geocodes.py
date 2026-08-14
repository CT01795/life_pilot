from datetime import datetime, timedelta, timezone
from typing import Any

from external.database import get_database_engine
from sqlalchemy import text


def get_geocode_cache(query_hash: str) -> dict[str, Any] | None:
    statement = text(
        """
        select id, status, lat, lng, expires_at
        from public.geocode_cache
        where query_hash = :query_hash
        """
    )

    with get_database_engine().connect() as connection:
        row = connection.execute(
            statement,
            {"query_hash": query_hash},
        ).mappings().one_or_none()
        return dict(row) if row is not None else None


def claim_geocode_refresh(query_hash: str) -> int | None:
    statement = text(
        """
        insert into public.geocode_cache (
          query_hash,
          status
        )
        values (
          :query_hash,
          'pending'
        )
        on conflict (query_hash)
        do update set
          status = 'pending',
          lat = null,
          lng = null,
          requested_at = now(),
          refreshed_at = null,
          expires_at = null,
          error_code = null,
          updated_at = now()
        where public.geocode_cache.status = 'failed'
           or (
             public.geocode_cache.status in ('success', 'not_found')
             and public.geocode_cache.expires_at <= now()
           )
           or (
             public.geocode_cache.status = 'pending'
             and public.geocode_cache.requested_at < now() - interval '2 minutes'
           )
        returning id
        """
    )

    with get_database_engine().begin() as connection:
        cache_id = connection.execute(
            statement,
            {"query_hash": query_hash},
        ).scalar_one_or_none()
        return int(cache_id) if cache_id is not None else None


def save_geocode_result(
    *,
    cache_id: int,
    lat: float | None,
    lng: float | None,
    ttl_days: int,
) -> None:
    found = lat is not None and lng is not None
    statement = text(
        """
        update public.geocode_cache
        set status = :status,
            lat = :lat,
            lng = :lng,
            refreshed_at = now(),
            expires_at = :expires_at,
            error_code = null,
            updated_at = now()
        where id = :cache_id
          and status = 'pending'
        """
    )
    expires_at = datetime.now(timezone.utc) + timedelta(days=ttl_days)

    with get_database_engine().begin() as connection:
        connection.execute(
            statement,
            {
                "cache_id": cache_id,
                "status": "success" if found else "not_found",
                "lat": lat if found else None,
                "lng": lng if found else None,
                "expires_at": expires_at,
            },
        )


def mark_geocode_failed(*, cache_id: int, error_code: str) -> None:
    statement = text(
        """
        update public.geocode_cache
        set status = 'failed',
            lat = null,
            lng = null,
            refreshed_at = now(),
            expires_at = null,
            error_code = :error_code,
            updated_at = now()
        where id = :cache_id
          and status = 'pending'
        """
    )

    with get_database_engine().begin() as connection:
        connection.execute(
            statement,
            {
                "cache_id": cache_id,
                "error_code": error_code[:100],
            },
        )
