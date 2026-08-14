import os
from datetime import date
from threading import Lock
from typing import Any

from sqlalchemy import Engine, create_engine, text


_engine: Engine | None = None
_engine_lock = Lock()


def _get_engine() -> Engine:
    global _engine

    if _engine is not None:
        return _engine

    with _engine_lock:
        if _engine is not None:
            return _engine

        database_url = os.getenv("DB_URL", "").strip()
        if not database_url:
            raise RuntimeError("Holiday database is not configured")

        _engine = create_engine(
            database_url,
            pool_pre_ping=True,
            pool_recycle=300,
        )
        return _engine


def claim_daily_sync(
    *,
    country_code: str,
    calendar_year: int,
    sync_date: date,
) -> int | None:
    statement = text(
        """
        insert into public.holiday_sync_runs (
          country_code,
          calendar_year,
          sync_date,
          status
        )
        values (
          :country_code,
          :calendar_year,
          :sync_date,
          'pending'
        )
        on conflict (country_code, calendar_year, sync_date)
        do update set
          status = 'pending',
          requested_at = now(),
          completed_at = null,
          error_code = null
        where public.holiday_sync_runs.status = 'failed'
           or (
             public.holiday_sync_runs.status = 'pending'
             and public.holiday_sync_runs.requested_at < now() - interval '5 minutes'
           )
        returning id
        """
    )

    with _get_engine().begin() as connection:
        sync_run_id = connection.execute(
            statement,
            {
                "country_code": country_code,
                "calendar_year": calendar_year,
                "sync_date": sync_date,
            },
        ).scalar_one_or_none()

    return int(sync_run_id) if sync_run_id is not None else None


def save_sync_result(
    *,
    sync_run_id: int,
    country_code: str,
    language_code: str,
    holidays: list[dict[str, Any]],
) -> None:
    upsert_statement = text(
        """
        insert into public.public_holidays (
          country_code,
          language_code,
          source_event_id,
          holiday_date,
          summary
        )
        values (
          :country_code,
          :language_code,
          :source_event_id,
          :holiday_date,
          :summary
        )
        on conflict (country_code, source_event_id)
        do update set
          language_code = excluded.language_code,
          holiday_date = excluded.holiday_date,
          summary = excluded.summary,
          updated_at = now(),
          last_seen_at = now()
        """
    )
    finish_statement = text(
        """
        update public.holiday_sync_runs
        set status = 'success',
            completed_at = now(),
            error_code = null
        where id = :sync_run_id
          and status = 'pending'
        """
    )

    rows = [
        {
            "country_code": country_code,
            "language_code": language_code,
            "source_event_id": holiday["source_event_id"],
            "holiday_date": holiday["holiday_date"],
            "summary": holiday["summary"],
        }
        for holiday in holidays
    ]

    with _get_engine().begin() as connection:
        if rows:
            connection.execute(upsert_statement, rows)
        connection.execute(finish_statement, {"sync_run_id": sync_run_id})


def mark_sync_failed(*, sync_run_id: int, error_code: str) -> None:
    statement = text(
        """
        update public.holiday_sync_runs
        set status = 'failed',
            completed_at = now(),
            error_code = :error_code
        where id = :sync_run_id
          and status = 'pending'
        """
    )

    with _get_engine().begin() as connection:
        connection.execute(
            statement,
            {
                "sync_run_id": sync_run_id,
                "error_code": error_code[:100],
            },
        )


def fetch_holidays(
    *,
    country_code: str,
    start_date: date,
    end_date: date,
) -> list[dict[str, Any]]:
    statement = text(
        """
        select source_event_id, holiday_date, summary
        from public.public_holidays
        where country_code = :country_code
          and holiday_date >= :start_date
          and holiday_date < :end_date
        order by holiday_date, source_event_id
        """
    )

    with _get_engine().connect() as connection:
        rows = connection.execute(
            statement,
            {
                "country_code": country_code,
                "start_date": start_date,
                "end_date": end_date,
            },
        ).mappings()
        return [dict(row) for row in rows]
