import hashlib
import os
import time
from typing import Annotated, Any

import httpx
from fastapi import Depends, Header, HTTPException, status


AUTH_TIMEOUT_SECONDS = 8.0
MAX_AUTHORIZATION_LENGTH = 4096
ADMIN_ROLE = "admin"
AUTH_CACHE_TTL_SECONDS = 60.0
AUTH_CACHE_MAX_ENTRIES = 256
_auth_user_cache: dict[str, tuple[float, dict[str, Any]]] = {}


def _authorization_cache_key(authorization: str) -> str:
    return hashlib.sha256(authorization.encode("utf-8")).hexdigest()


def _get_cached_user(authorization: str) -> dict[str, Any] | None:
    cache_key = _authorization_cache_key(authorization)
    cached = _auth_user_cache.get(cache_key)
    if cached is None:
        return None

    expires_at, user = cached
    if expires_at <= time.monotonic():
        _auth_user_cache.pop(cache_key, None)
        return None

    return user


def _cache_user(authorization: str, user: dict[str, Any]) -> None:
    now = time.monotonic()
    expired_keys = [
        cache_key
        for cache_key, (expires_at, _) in _auth_user_cache.items()
        if expires_at <= now
    ]
    for cache_key in expired_keys:
        _auth_user_cache.pop(cache_key, None)

    while len(_auth_user_cache) >= AUTH_CACHE_MAX_ENTRIES:
        _auth_user_cache.pop(next(iter(_auth_user_cache)))

    _auth_user_cache[_authorization_cache_key(authorization)] = (
        now + AUTH_CACHE_TTL_SECONDS,
        user,
    )


def _clear_auth_cache() -> None:
    _auth_user_cache.clear()


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

    cached_user = _get_cached_user(authorization)
    if cached_user is not None:
        return cached_user

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

    _cache_user(authorization, user)
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
