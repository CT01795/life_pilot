import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException, status

from security import supabase_auth
from security.supabase_auth import require_supabase_admin


class SupabaseUserCacheTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        supabase_auth._clear_auth_cache()

    def tearDown(self):
        supabase_auth._clear_auth_cache()

    @staticmethod
    def _provider_context(status_code=200):
        response = MagicMock()
        response.status_code = status_code
        response.json.return_value = {
            "id": "cached-user-id",
            "app_metadata": {"role": "admin"},
        }
        client = AsyncMock()
        client.get.return_value = response
        context = MagicMock()
        context.__aenter__ = AsyncMock(return_value=client)
        context.__aexit__ = AsyncMock(return_value=False)
        return context, client

    async def test_reuses_successful_authentication_for_same_token(self):
        context, client = self._provider_context()

        with (
            patch.object(
                supabase_auth,
                "_get_supabase_config",
                return_value=("https://example.supabase.co", "anon-key"),
            ),
            patch.object(
                supabase_auth.httpx,
                "AsyncClient",
                return_value=context,
            ),
        ):
            first_user = await supabase_auth.require_supabase_user(
                "Bearer shared-token"
            )
            second_user = await supabase_auth.require_supabase_user(
                "Bearer shared-token"
            )

        self.assertEqual(first_user, second_user)
        client.get.assert_awaited_once()

    async def test_revalidates_after_cache_expiration(self):
        context, client = self._provider_context()

        with (
            patch.object(
                supabase_auth,
                "AUTH_CACHE_TTL_SECONDS",
                0,
            ),
            patch.object(
                supabase_auth,
                "_get_supabase_config",
                return_value=("https://example.supabase.co", "anon-key"),
            ),
            patch.object(
                supabase_auth.httpx,
                "AsyncClient",
                return_value=context,
            ),
        ):
            await supabase_auth.require_supabase_user("Bearer expiring-token")
            await supabase_auth.require_supabase_user("Bearer expiring-token")

        self.assertEqual(client.get.await_count, 2)

    async def test_does_not_cache_rejected_token(self):
        context, client = self._provider_context(status_code=401)

        with (
            patch.object(
                supabase_auth,
                "_get_supabase_config",
                return_value=("https://example.supabase.co", "anon-key"),
            ),
            patch.object(
                supabase_auth.httpx,
                "AsyncClient",
                return_value=context,
            ),
        ):
            for _ in range(2):
                with self.assertRaises(HTTPException):
                    await supabase_auth.require_supabase_user(
                        "Bearer rejected-token"
                    )

        self.assertEqual(client.get.await_count, 2)


class SupabaseAdminAuthorizationTest(unittest.TestCase):
    def test_accepts_user_with_server_admin_role(self):
        user = {
            "id": "admin-user-id",
            "app_metadata": {"role": "admin"},
        }

        self.assertIs(require_supabase_admin(user), user)

    def test_rejects_non_admin_user(self):
        user = {
            "id": "regular-user-id",
            "app_metadata": {"role": "user"},
        }

        with self.assertRaises(HTTPException) as context:
            require_supabase_admin(user)

        self.assertEqual(
            context.exception.status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(
            context.exception.detail,
            "Administrator access required",
        )

    def test_rejects_missing_or_invalid_app_metadata(self):
        for app_metadata in (None, "admin", {}, {"role": "Admin"}):
            with self.subTest(app_metadata=app_metadata):
                with self.assertRaises(HTTPException) as context:
                    require_supabase_admin(
                        {
                            "id": "invalid-metadata-user-id",
                            "app_metadata": app_metadata,
                        }
                    )

                self.assertEqual(
                    context.exception.status_code,
                    status.HTTP_403_FORBIDDEN,
                )


if __name__ == "__main__":
    unittest.main()
