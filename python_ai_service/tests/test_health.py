import os
import unittest

from fastapi.testclient import TestClient

os.environ.setdefault("DB_URL", "sqlite:///:memory:")

from app import app


class HealthEndpointTest(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_health_endpoint_returns_ok(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_cors_allows_github_pages(self):
        origin = "https://ct01795.github.io"

        response = self.client.get("/health", headers={"Origin": origin})

        self.assertEqual(response.headers.get("access-control-allow-origin"), origin)

    def test_cors_allows_local_development(self):
        origin = "http://localhost:11036"

        response = self.client.get("/health", headers={"Origin": origin})

        self.assertEqual(response.headers.get("access-control-allow-origin"), origin)

    def test_cors_rejects_unknown_websites(self):
        response = self.client.get(
            "/health",
            headers={"Origin": "https://malicious.example"},
        )

        self.assertNotIn("access-control-allow-origin", response.headers)


if __name__ == "__main__":
    unittest.main()
