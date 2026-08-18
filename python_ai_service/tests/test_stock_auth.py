import os
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

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


if __name__ == "__main__":
    unittest.main()
