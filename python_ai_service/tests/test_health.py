import os
import unittest

from fastapi.testclient import TestClient

os.environ.setdefault("DB_URL", "sqlite:///:memory:")

from app import app


class HealthEndpointTest(unittest.TestCase):
    def test_health_endpoint_returns_ok(self):
        response = TestClient(app).get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")


if __name__ == "__main__":
    unittest.main()
