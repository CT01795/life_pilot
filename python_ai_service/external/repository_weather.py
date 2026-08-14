import json
from datetime import datetime
from typing import Any

from external.database import get_database_engine
from sqlalchemy import text


def get_weather_forecast_cache(cache_key: str) -> dict[str, Any] | None:
    statement = text(
        """
        select forecast, expires_at
        from public.weather_forecast_cache
        where cache_key = :cache_key
          and expires_at > now()
        """
    )

    with get_database_engine().connect() as connection:
        row = connection.execute(
            statement,
            {"cache_key": cache_key},
        ).mappings().one_or_none()
        return dict(row) if row is not None else None


def save_weather_forecast_cache(
    *,
    cache_key: str,
    forecast: list[dict[str, Any]],
    expires_at: datetime,
) -> None:
    delete_expired_statement = text(
        """
        delete from public.weather_forecast_cache
        where expires_at <= now()
        """
    )
    upsert_statement = text(
        """
        insert into public.weather_forecast_cache (
          cache_key,
          forecast,
          expires_at
        )
        values (
          :cache_key,
          cast(:forecast as jsonb),
          :expires_at
        )
        on conflict (cache_key)
        do update set
          forecast = excluded.forecast,
          expires_at = excluded.expires_at,
          updated_at = now()
        """
    )

    with get_database_engine().begin() as connection:
        connection.execute(delete_expired_statement)
        connection.execute(
            upsert_statement,
            {
                "cache_key": cache_key,
                "forecast": json.dumps(
                    forecast,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
                "expires_at": expires_at,
            },
        )
