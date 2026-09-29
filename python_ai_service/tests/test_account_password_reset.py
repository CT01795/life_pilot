import os
import string
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException, status

os.environ.setdefault("DB_URL", "sqlite:///:memory:")

from account import service_account


class TemporaryPasswordTest(unittest.TestCase):
    def test_generated_password_meets_common_strength_rules(self):
        password = service_account._generate_temporary_password()

        self.assertEqual(len(password), 16)
        self.assertTrue(any(character in string.ascii_uppercase for character in password))
        self.assertTrue(any(character in string.ascii_lowercase for character in password))
        self.assertTrue(any(character in string.digits for character in password))
        self.assertTrue(any(character in "!@#$%" for character in password))


class AdminPasswordResetEndpointTest(unittest.IsolatedAsyncioTestCase):
    async def test_admin_receives_temporary_password_for_existing_user(self):
        with (
            patch.object(service_account, "_find_user_id", return_value="user-id"),
            patch.object(
                service_account,
                "_update_user_password",
                new=AsyncMock(),
            ) as update_password,
            patch.object(
                service_account,
                "_generate_temporary_password",
                return_value="Temporary1!Pass",
            ),
        ):
            result = await service_account.reset_user_password_as_admin(
                service_account.AdminPasswordResetPayload(
                    email=" User@Example.com ",
                ),
                {"id": "admin-id", "app_metadata": {"role": "admin"}},
            )

        self.assertEqual(result["email"], "user@example.com")
        self.assertEqual(result["temporary_password"], "Temporary1!Pass")
        update_password.assert_awaited_once_with("user-id", "Temporary1!Pass")

    async def test_missing_user_is_reported_without_changing_a_password(self):
        with (
            patch.object(service_account, "_find_user_id", return_value=None),
            patch.object(
                service_account,
                "_update_user_password",
                new=AsyncMock(),
            ) as update_password,
        ):
            with self.assertRaises(HTTPException) as context:
                await service_account.reset_user_password_as_admin(
                    service_account.AdminPasswordResetPayload(
                        email="missing@example.com",
                    ),
                    {"id": "admin-id", "app_metadata": {"role": "admin"}},
                )

        self.assertEqual(context.exception.status_code, status.HTTP_404_NOT_FOUND)
        update_password.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
