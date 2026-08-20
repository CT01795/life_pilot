import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from sqlalchemy.exc import SQLAlchemyError

os.environ.setdefault("DB_URL", "sqlite:///:memory:")

from app import app
from security.supabase_auth import require_supabase_user
from stock import service_stock


class StockAuthorizationTest(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides.clear()
        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides.clear()
        if service_stock._model_training_lock.locked():
            service_stock._model_training_lock.release()
        service_stock._set_model_training_state("idle")

    def test_rejects_request_without_authentication(self):
        response = self.client.post("/stock/backtest_model")

        self.assertEqual(response.status_code, 401)

    def test_rejects_authenticated_non_admin_user(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }

        response = self.client.post("/stock/backtest_model")

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

        response = self.client.post("/stock/backtest_model")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["stocks"], [])

    def test_rejects_duplicate_model_training(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        service_stock._model_training_lock.acquire()

        response = self.client.post("/stock/update_model")

        self.assertEqual(response.status_code, 409)
        self.assertEqual(
            response.json()["detail"],
            "Model training is already in progress",
        )

    def test_model_training_releases_lock_after_success(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        with patch("stock.service_stock.train_and_save_model") as train_model:
            response = self.client.post("/stock/update_model")

        self.assertEqual(response.status_code, 200)
        train_model.assert_called_once_with()
        self.assertFalse(service_stock._model_training_lock.locked())
        status_response = self.client.get("/stock/model_training_status")
        status = status_response.json()
        self.assertEqual(status["status"], "succeeded")
        self.assertIsNotNone(status["started_at"])
        self.assertIsNotNone(status["finished_at"])

    def test_model_training_releases_lock_after_failure(self):
        service_stock._model_training_lock.acquire()
        service_stock._set_model_training_state(
            "training",
            started_at="2026-08-18T00:00:00+00:00",
        )

        with patch(
            "stock.service_stock.train_and_save_model",
            side_effect=RuntimeError("training failed"),
        ), self.assertRaises(RuntimeError):
            service_stock._run_model_training()

        self.assertFalse(service_stock._model_training_lock.locked())
        status = service_stock._get_model_training_state()
        self.assertEqual(status["status"], "failed")
        self.assertEqual(status["started_at"], "2026-08-18T00:00:00+00:00")
        self.assertIsNotNone(status["finished_at"])

    def test_model_training_status_requires_admin(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }

        response = self.client.get("/stock/model_training_status")

        self.assertEqual(response.status_code, 403)

    def test_stock_date_batch_rejects_unknown_table(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        response = self.client.post(
            "/stock/insert_stock_date_batch",
            json={
                "table_name": "another_table",
                "stocks": [{"type": "daily", "date": "2026-08-20T00:00:00Z"}],
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_stock_date_batch_reports_inserted_and_skipped_rows(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.return_value.rowcount = 1

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_stock_date_batch",
                json={
                    "table_name": "stock_date",
                    "stocks": [
                        {"type": "daily", "date": "2026-08-20T00:00:00Z"},
                        {"type": "daily", "date": "2026-08-20T00:00:00Z"},
                    ],
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "status": "ok",
                "received_rows": 2,
                "inserted_rows": 1,
                "skipped_rows": 1,
            },
        )
        db.commit.assert_called_once_with()
        db.close.assert_called_once_with()

    def test_stock_date_batch_rolls_back_database_failure(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.side_effect = SQLAlchemyError("database unavailable")

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_stock_date_batch",
                json={
                    "table_name": "stock_date",
                    "stocks": [
                        {"type": "daily", "date": "2026-08-20T00:00:00Z"},
                    ],
                },
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"],
            "Stock date batch could not be saved",
        )
        db.rollback.assert_called_once_with()
        db.commit.assert_not_called()
        db.close.assert_called_once_with()

    def test_stock_daily_price_batch_rejects_unknown_table(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        response = self.client.post(
            "/stock/insert_stock_daily_price_batch",
            json={
                "table_name": "stock_date",
                "stocks": [
                    {
                        "security_code": "2330",
                        "date": "2026-08-20T00:00:00Z",
                    },
                ],
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_stock_daily_price_batch_reports_duplicate_rows(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.return_value.rowcount = 1

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_stock_daily_price_batch",
                json={
                    "table_name": "stock_daily_price",
                    "stocks": [
                        {
                            "security_code": "2330",
                            "security_name": "TSMC",
                            "date": "2026-08-20T00:00:00Z",
                            "closing_price": 1200,
                        },
                        {
                            "security_code": "2330",
                            "security_name": "TSMC",
                            "date": "2026-08-20T00:00:00Z",
                            "closing_price": 1200,
                        },
                    ],
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "status": "ok",
                "received_rows": 2,
                "inserted_rows": 1,
                "skipped_rows": 1,
            },
        )
        db.commit.assert_called_once_with()
        db.close.assert_called_once_with()

    def test_stock_daily_price_batch_rolls_back_database_failure(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.side_effect = SQLAlchemyError("database unavailable")

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_stock_daily_price_batch",
                json={
                    "table_name": "stock_daily_price",
                    "stocks": [
                        {
                            "security_code": "2330",
                            "date": "2026-08-20T00:00:00Z",
                        },
                    ],
                },
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"],
            "Stock daily price batch could not be saved",
        )
        db.rollback.assert_called_once_with()
        db.commit.assert_not_called()
        db.close.assert_called_once_with()

    def test_futures_institutional_batch_rejects_unknown_table(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        response = self.client.post(
            "/stock/insert_futures_institutional_batch",
            json={
                "table_name": "another_table",
                "futures": [
                    {
                        "date": "2026-08-20T00:00:00Z",
                        "product_name": "Taiwan futures",
                        "identity_type": "foreign investor",
                    },
                ],
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_futures_institutional_batch_reports_duplicate_rows(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.return_value.rowcount = 1
        item = {
            "date": "2026-08-20T00:00:00Z",
            "product_name": "Taiwan futures",
            "identity_type": "foreign investor",
            "trade_long_qty": 100,
        }

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_futures_institutional_batch",
                json={
                    "table_name": "futures_institutional",
                    "futures": [item, item],
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "status": "ok",
                "received_rows": 2,
                "inserted_rows": 1,
                "skipped_rows": 1,
            },
        )
        db.commit.assert_called_once_with()
        db.close.assert_called_once_with()

    def test_futures_institutional_batch_rolls_back_database_failure(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.side_effect = SQLAlchemyError("database unavailable")

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_futures_institutional_batch",
                json={
                    "table_name": "futures_institutional",
                    "futures": [
                        {
                            "date": "2026-08-20T00:00:00Z",
                            "product_name": "Taiwan futures",
                            "identity_type": "foreign investor",
                        },
                    ],
                },
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"],
            "Futures institutional batch could not be saved",
        )
        db.rollback.assert_called_once_with()
        db.commit.assert_not_called()
        db.close.assert_called_once_with()

    def test_stock_institutional_batch_rejects_unknown_table(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        response = self.client.post(
            "/stock/insert_stock_institutional_batch",
            json={
                "table_name": "another_table",
                "stocks": [
                    {
                        "date": "2026-08-20T00:00:00Z",
                        "stock_no": "2330",
                    },
                ],
            },
        )

        self.assertEqual(response.status_code, 422)

    def test_stock_institutional_batch_reports_duplicate_rows(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.return_value.rowcount = 1
        item = {
            "date": "2026-08-20T00:00:00Z",
            "stock_no": "2330",
            "stock_name": "TSMC",
            "foreign_buy": 100,
            "source": "twse",
        }

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_stock_institutional_batch",
                json={
                    "table_name": "stock_institutional",
                    "stocks": [item, item],
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "status": "ok",
                "received_rows": 2,
                "inserted_rows": 1,
                "skipped_rows": 1,
            },
        )
        db.commit.assert_called_once_with()
        db.close.assert_called_once_with()

    def test_stock_institutional_batch_rolls_back_database_failure(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.execute.side_effect = SQLAlchemyError("database unavailable")

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/insert_stock_institutional_batch",
                json={
                    "table_name": "stock_institutional",
                    "stocks": [
                        {
                            "date": "2026-08-20T00:00:00Z",
                            "stock_no": "2330",
                        },
                    ],
                },
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"],
            "Stock institutional batch could not be saved",
        )
        db.rollback.assert_called_once_with()
        db.commit.assert_not_called()
        db.close.assert_called_once_with()

    def test_stock_cleanup_endpoints_reject_wrong_tables(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        cases = (
            ("/stock/delete_stock_daily_price", "stock_date"),
            ("/stock/delete_stock_date", "stock_daily_price"),
        )

        for endpoint, table_name in cases:
            with self.subTest(endpoint=endpoint):
                response = self.client.post(
                    endpoint,
                    json={
                        "table_name": table_name,
                        "date": "2025-08-20T00:00:00Z",
                    },
                )

                self.assertEqual(response.status_code, 422)

    def test_stock_cleanup_endpoints_reject_recent_cutoff(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        cases = (
            ("/stock/delete_stock_daily_price", "stock_daily_price"),
            ("/stock/delete_stock_date", "stock_date"),
        )
        recent_cutoff = datetime.now(timezone.utc).isoformat()

        for endpoint, table_name in cases:
            with self.subTest(endpoint=endpoint):
                response = self.client.post(
                    endpoint,
                    json={
                        "table_name": table_name,
                        "date": recent_cutoff,
                    },
                )

                self.assertEqual(response.status_code, 422)
                self.assertEqual(
                    response.json()["detail"],
                    "Stock cleanup cutoff must be at least 30 days old",
                )

    def test_stock_cleanup_reports_deleted_rows(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.query.return_value.filter.return_value.delete.return_value = 42
        safe_cutoff = (
            datetime.now(timezone.utc) - timedelta(days=370)
        ).isoformat()

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/delete_stock_daily_price",
                json={
                    "table_name": "stock_daily_price",
                    "date": safe_cutoff,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"status": "ok", "deleted_rows": 42},
        )
        db.commit.assert_called_once_with()
        db.close.assert_called_once_with()

    def test_stock_cleanup_rolls_back_database_failure(self):
        app.dependency_overrides[require_supabase_user] = lambda: {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }
        db = MagicMock()
        db.query.side_effect = SQLAlchemyError("database unavailable")
        safe_cutoff = (
            datetime.now(timezone.utc) - timedelta(days=370)
        ).isoformat()

        with patch("stock.service_stock.SessionLocal", return_value=db):
            response = self.client.post(
                "/stock/delete_stock_date",
                json={
                    "table_name": "stock_date",
                    "date": safe_cutoff,
                },
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()["detail"],
            "Stock cleanup could not be completed",
        )
        db.rollback.assert_called_once_with()
        db.commit.assert_not_called()
        db.close.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
