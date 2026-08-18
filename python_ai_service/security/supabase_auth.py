import os
from typing import Annotated, Any

import httpx
from fastapi import Depends, Header, HTTPException, status


AUTH_TIMEOUT_SECONDS = 8.0
MAX_AUTHORIZATION_LENGTH = 4096
ADMIN_ROLE = "admin"


def _get_supabase_config() -> tuple[str, str]:
    supabase_url = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
    supabase_anon_key = os.getenv("SUPABASE_ANON_KEY", "").strip()

    if not supabase_url or not supabase_anon_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is not configured",
        )

    return supabase_url, supabase_anon_key


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication token",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def require_supabase_user(
    authorization: Annotated[str | None, Header()] = None,
) -> dict[str, Any]:
    if (
        authorization is None
        or len(authorization) > MAX_AUTHORIZATION_LENGTH
        or not authorization.startswith("Bearer ")
        or not authorization.removeprefix("Bearer ").strip()
    ):
        raise _unauthorized()

    supabase_url, supabase_anon_key = _get_supabase_config()

    try:
        async with httpx.AsyncClient(timeout=AUTH_TIMEOUT_SECONDS) as client:
            response = await client.get(
                f"{supabase_url}/auth/v1/user",
                headers={
                    "Authorization": authorization,
                    "apikey": supabase_anon_key,
                },
            )
    except httpx.HTTPError as exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is temporarily unavailable",
        ) from exception

    if response.status_code != status.HTTP_200_OK:
        raise _unauthorized()

    try:
        user = response.json()
    except ValueError as exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service returned an invalid response",
        ) from exception

    if not isinstance(user, dict) or not user.get("id"):
        raise _unauthorized()

    return user


def require_supabase_admin(
    user: Annotated[dict[str, Any], Depends(require_supabase_user)],
) -> dict[str, Any]:
    app_metadata = user.get("app_metadata")
    if (
        not isinstance(app_metadata, dict)
        or app_metadata.get("role") != ADMIN_ROLE
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required",
        )

    return user
