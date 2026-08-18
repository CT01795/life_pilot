import unittest

from fastapi import HTTPException, status

from security.supabase_auth import require_supabase_admin


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
