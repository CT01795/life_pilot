import os
import unittest
from unittest.mock import MagicMock, patch

import requests
from fastapi.testclient import TestClient

os.environ.setdefault("DB_URL", "sqlite:///:memory:")

from app import app
from security.supabase_auth import require_supabase_user


class EventProxyAuthorizationTest(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides.clear()
        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides.clear()

    def _request(self):
        return self.client.post(
            "/event/get_url_data",
            json={
                "url": "https://www.twse.com.tw/exchangeReport/MI_INDEX?response=json",
                "method": "GET",
            },
        )

    def test_rejects_request_without_authentication(self):
        response = self._request()

        self.assertEqual(response.status_code, 401)

    def test_rejects_authenticated_non_admin_user(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }

        response = self._request()

        self.assertEqual(response.status_code, 403)
        self.assertEqual(
            response.json()["detail"],
            "Administrator access required",
        )

    def test_allows_authenticated_admin_user(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        provider_response = MagicMock()
        provider_response.encoding = "utf-8"
        provider_response.content = b"provider response"
        provider_response.text = "provider response"
        provider_response.raise_for_status.return_value = None

        with patch(
            "event.service_event.requests.get",
            return_value=provider_response,
        ) as provider_get:
            response = self._request()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        provider_get.assert_called_once()
        _, request_kwargs = provider_get.call_args
        self.assertFalse(request_kwargs["allow_redirects"])
        self.assertNotIn("verify", request_kwargs)

    def test_allows_authenticated_user_to_proxy_public_event_source(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        provider_response = MagicMock()
        provider_response.encoding = "utf-8"
        provider_response.content = b"provider response"
        provider_response.text = "provider response"
        provider_response.raise_for_status.return_value = None

        with patch(
            "event.service_event.requests.get",
            return_value=provider_response,
        ):
            response = self.client.post(
                "/event/get_public_event_url_data",
                json={
                    "url": "https://www.taiwan.net.tw/m1.aspx?sNo=0001019",
                    "method": "GET",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_public_event_proxy_rejects_other_allowed_sources(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }

        response = self.client.post(
            "/event/get_public_event_url_data",
            json={
                "url": "https://www.twse.com.tw/exchangeReport/MI_INDEX",
                "method": "GET",
            },
        )

        self.assertEqual(response.status_code, 403)

    def test_authenticated_user_can_check_public_event_update_status(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        db = MagicMock()
        first_result = MagicMock()
        first_result.scalar.return_value = True
        second_result = MagicMock()
        second_result.scalar.return_value = False
        db.execute.side_effect = [first_result, second_result]

        with patch("event.service_event.SessionLocal", return_value=db):
            response = self.client.get("/event/public_events_updated_today")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"updated": True, "running": False},
        )
        db.close.assert_called_once()

    def test_authenticated_user_can_claim_public_event_refresh(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        claim = {
            "acquired": True,
            "updated": False,
            "token": "123e4567-e89b-12d3-a456-426614174000",
        }

        with patch(
            "event.service_event._start_public_event_refresh",
            return_value=claim,
        ):
            response = self.client.post("/event/start_public_event_refresh")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), claim)

    def test_authenticated_user_can_complete_public_event_refresh(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        token = "123e4567-e89b-12d3-a456-426614174000"

        with patch(
            "event.service_event._finish_public_event_refresh",
        ) as finish:
            response = self.client.post(
                "/event/complete_public_event_refresh",
                json={"token": token},
            )

        self.assertEqual(response.status_code, 200)
        finish.assert_called_once_with(token, completed=True)

    def test_authenticated_user_can_abort_public_event_refresh(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        token = "123e4567-e89b-12d3-a456-426614174000"

        with patch(
            "event.service_event._finish_public_event_refresh",
        ) as finish:
            response = self.client.post(
                "/event/abort_public_event_refresh",
                json={"token": token},
            )

        self.assertEqual(response.status_code, 200)
        finish.assert_called_once_with(token, completed=False)

    def test_refresh_batch_endpoints_require_authentication(self):
        for path in (
            "/event/start_public_event_refresh",
            "/event/complete_public_event_refresh",
            "/event/abort_public_event_refresh",
            "/event/heartbeat_public_event_refresh",
        ):
            with self.subTest(path=path):
                response = self.client.post(
                    path,
                    json={"token": "123e4567-e89b-12d3-a456-426614174000"},
                )
                self.assertEqual(response.status_code, 401)

    def test_authenticated_user_can_heartbeat_public_event_refresh(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        token = "123e4567-e89b-12d3-a456-426614174000"

        with patch(
            "event.service_event._heartbeat_public_event_refresh",
        ) as heartbeat:
            response = self.client.post(
                "/event/heartbeat_public_event_refresh",
                json={"token": token},
            )

        self.assertEqual(response.status_code, 200)
        heartbeat.assert_called_once_with(token)

    def test_authenticated_user_can_submit_pending_public_events(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }
        events = [
            {
                "id": "event-1",
                "name": "Public event",
                "start_date": "2026-08-24",
                "account": "attacker@example.com",
                "is_approved": True,
            }
        ]

        with patch(
            "event.service_event._insert_public_events",
            return_value=1,
        ) as insert_events:
            response = self.client.post(
                "/event/import_public_events",
                json={
                    "source_url": "https://strolltimes.com/weekend.json",
                    "events": events,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["inserted_rows"], 1)
        insert_events.assert_called_once_with(
            events,
            "https://strolltimes.com/weekend.json",
        )

    def test_public_event_sanitizer_forces_admin_owner_and_pending_status(self):
        from event.service_event import (
            SYSTEM_EVENT_OWNER_EMAIL,
            _sanitize_public_event,
        )

        sanitized = _sanitize_public_event(
            {
                "id": "event-1",
                "name": "Public event",
                "start_date": "2026-08-24",
                "account": "attacker@example.com",
                "is_approved": True,
            },
            "https://strolltimes.com/weekend.json",
        )

        self.assertEqual(sanitized["account"], SYSTEM_EVENT_OWNER_EMAIL)
        self.assertFalse(sanitized["is_approved"])
        self.assertEqual(
            sanitized["source"],
            "https://strolltimes.com/weekend.json",
        )

    def test_public_event_import_rejects_unapproved_source(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }

        response = self.client.post(
            "/event/import_public_events",
            json={
                "source_url": "https://example.com/events.json",
                "events": [
                    {
                        "id": "event-1",
                        "name": "Public event",
                        "start_date": "2026-08-24",
                    }
                ],
            },
        )

        self.assertEqual(response.status_code, 403)

    def test_rejects_non_https_target(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        response = self.client.post(
            "/event/get_url_data",
            json={
                "url": "http://www.twse.com.tw/exchangeReport/MI_INDEX",
                "method": "GET",
            },
        )

        self.assertEqual(response.status_code, 400)

    def test_rejects_unapproved_host_and_lookalike(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        for url in (
            "https://example.com/exchangeReport/MI_INDEX",
            "https://www.twse.com.tw.attacker.example/exchangeReport/MI_INDEX",
        ):
            with self.subTest(url=url):
                response = self.client.post(
                    "/event/get_url_data",
                    json={"url": url, "method": "GET"},
                )
                self.assertEqual(response.status_code, 403)

    def test_rejects_unapproved_path(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        response = self.client.post(
            "/event/get_url_data",
            json={
                "url": "https://www.twse.com.tw/private/path",
                "method": "GET",
            },
        )

        self.assertEqual(response.status_code, 403)

    def test_allows_approved_post_target(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        provider_response = MagicMock()
        provider_response.encoding = "utf-8"
        provider_response.content = b"provider response"
        provider_response.text = "provider response"
        provider_response.raise_for_status.return_value = None

        with patch(
            "event.service_event.requests.post",
            return_value=provider_response,
        ) as provider_post:
            response = self.client.post(
                "/event/get_url_data",
                json={
                    "url": "https://www.tpex.org.tw/www/zh-tw/insti/dailyTrade",
                    "method": "POST",
                    "body": {"type": "Daily"},
                },
            )

        self.assertEqual(response.status_code, 200)
        provider_post.assert_called_once()

    def test_hides_provider_error_details_from_client(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        internal_error = "connection failed with internal host details"

        with patch(
            "event.service_event.requests.get",
            side_effect=requests.RequestException(internal_error),
        ), self.assertLogs("event.service_event", level="ERROR") as logs:
            response = self._request()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "status": "error",
                "message": "External service request failed",
            },
        )
        self.assertNotIn(internal_error, response.text)
        self.assertIn(internal_error, "\n".join(logs.output))


if __name__ == "__main__":
    unittest.main()
