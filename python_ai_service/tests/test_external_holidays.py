import unittest
from datetime import date, datetime, timezone
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException, status

from external import service_external


class ExternalHolidaysTest(unittest.IsolatedAsyncioTestCase):
    def _request(self, language_code: str = "zh") -> service_external.HolidayRequest:
        return service_external.HolidayRequest(
            start=datetime(2026, 1, 1, tzinfo=timezone.utc),
            end=datetime(2027, 1, 1, tzinfo=timezone.utc),
            language_code=language_code,
        )

    def test_languages_map_to_expected_country_calendars(self):
        self.assertEqual(service_external.HOLIDAY_CALENDARS["zh"][0], "TW")
        self.assertEqual(service_external.HOLIDAY_CALENDARS["en"][0], "US")
        self.assertEqual(service_external.HOLIDAY_CALENDARS["ja"][0], "JP")
        self.assertEqual(service_external.HOLIDAY_CALENDARS["ko"][0], "KR")

    async def test_repeated_request_does_not_sync_google_twice(self):
        stored_rows = [
            {
                "source_event_id": "holiday-1",
                "holiday_date": date(2026, 1, 1),
                "summary": "New Year's Day",
            }
        ]
        google_rows = [
            {
                "source_event_id": "holiday-1",
                "holiday_date": date(2026, 1, 1),
                "summary": "New Year's Day",
                "language_code": "en",
            }
        ]

        with (
            patch.object(
                service_external,
                "claim_daily_sync",
                side_effect=[101, None],
            ) as claim_sync,
            patch.object(
                service_external,
                "_fetch_google_holidays",
                new=AsyncMock(return_value=google_rows),
            ) as fetch_google,
            patch.object(service_external, "save_sync_result") as save_result,
            patch.object(
                service_external,
                "fetch_holidays",
                return_value=stored_rows,
            ),
        ):
            first = await service_external.get_holidays(
                self._request("en"),
                {"id": "repeat-test-user"},
            )
            second = await service_external.get_holidays(
                self._request("en"),
                {"id": "repeat-test-user"},
            )

        self.assertEqual(first.items, second.items)
        self.assertEqual(claim_sync.call_count, 2)
        fetch_google.assert_awaited_once()
        save_result.assert_called_once()
        self.assertEqual(save_result.call_args.kwargs["country_code"], "US")
        self.assertEqual(save_result.call_args.kwargs["language_code"], "en")

    async def test_google_failure_returns_existing_database_rows(self):
        stored_rows = [
            {
                "source_event_id": "holiday-2",
                "holiday_date": date(2026, 2, 28),
                "summary": "Peace Memorial Day",
            }
        ]
        provider_error = HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Holiday provider is temporarily unavailable",
        )

        with (
            patch.object(service_external, "claim_daily_sync", return_value=202),
            patch.object(
                service_external,
                "_fetch_google_holidays",
                new=AsyncMock(side_effect=provider_error),
            ),
            patch.object(service_external, "mark_sync_failed") as mark_failed,
            patch.object(
                service_external,
                "fetch_holidays",
                return_value=stored_rows,
            ),
        ):
            response = await service_external.get_holidays(
                self._request("zh"),
                {"id": "fallback-test-user"},
            )

        self.assertEqual(len(response.items), 1)
        self.assertEqual(response.items[0].date, "2026-02-28")
        self.assertEqual(response.items[0].summary, "Peace Memorial Day")
        mark_failed.assert_called_once_with(
            sync_run_id=202,
            error_code="google_provider_error",
        )


if __name__ == "__main__":
    unittest.main()
