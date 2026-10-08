import os
import secrets
import string
from typing import Annotated, Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text

from config import engine
from security.supabase_auth import require_supabase_admin


router = APIRouter(prefix="/account", tags=["account"])
ADMIN_AUTH_TIMEOUT_SECONDS = 10.0


class AdminPasswordResetPayload(BaseModel):
    email: str


class AdminAccountCreatePayload(BaseModel):
    email: str
    account_type: str = "personal"


def _generate_temporary_password(length: int = 16) -> str:
    if length < 12:
        raise ValueError("Temporary passwords must contain at least 12 characters")

    required = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice("!@#$%"),
    ]
    alphabet = string.ascii_letters + string.digits + "!@#$%"
    characters = required + [
        secrets.choice(alphabet) for _ in range(length - len(required))
    ]
    secrets.SystemRandom().shuffle(characters)
    return "".join(characters)


def _find_user_id(email: str) -> str | None:
    with engine.connect() as connection:
        user_id = connection.execute(
            text(
                """
                select id::text
                from auth.users
                where lower(email) = :email
                limit 1
                """
            ),
            {"email": email},
        ).scalar_one_or_none()
    return str(user_id) if user_id is not None else None


def _find_user_status(email: str) -> tuple[str, bool] | None:
    with engine.connect() as connection:
        row = connection.execute(
            text(
                """
                select id::text, email_confirmed_at is not null as confirmed
                from auth.users
                where lower(email) = :email
                limit 1
                """
            ),
            {"email": email},
        ).mappings().one_or_none()
    if row is None:
        return None
    return str(row["id"]), bool(row["confirmed"])


def _get_admin_auth_config() -> tuple[str, str]:
    supabase_url = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
    service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not supabase_url or not service_role_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Administrator password reset is not configured",
        )
    return supabase_url, service_role_key


async def _update_user_password(user_id: str, password: str) -> None:
    supabase_url, service_role_key = _get_admin_auth_config()
    try:
        async with httpx.AsyncClient(timeout=ADMIN_AUTH_TIMEOUT_SECONDS) as client:
            response = await client.put(
                f"{supabase_url}/auth/v1/admin/users/{user_id}",
                headers={
                    "Authorization": f"Bearer {service_role_key}",
                    "apikey": service_role_key,
                    "Content-Type": "application/json",
                },
                json={"password": password},
            )
    except httpx.HTTPError as exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is temporarily unavailable",
        ) from exception

    if response.status_code != status.HTTP_200_OK:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication service rejected the password update",
        )


async def _create_user(email: str, password: str, account_type: str) -> None:
    supabase_url, service_role_key = _get_admin_auth_config()
    try:
        async with httpx.AsyncClient(timeout=ADMIN_AUTH_TIMEOUT_SECONDS) as client:
            response = await client.post(
                f"{supabase_url}/auth/v1/admin/users",
                headers={
                    "Authorization": f"Bearer {service_role_key}",
                    "apikey": service_role_key,
                    "Content-Type": "application/json",
                },
                json={
                    "email": email,
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {"account_type": account_type},
                },
            )
    except httpx.HTTPError as exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is temporarily unavailable",
        ) from exception

    if response.status_code not in (status.HTTP_200_OK, status.HTTP_201_CREATED):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication service rejected the account creation",
        )


async def _approve_pending_user(
    user_id: str, password: str, account_type: str
) -> None:
    supabase_url, service_role_key = _get_admin_auth_config()
    try:
        async with httpx.AsyncClient(timeout=ADMIN_AUTH_TIMEOUT_SECONDS) as client:
            response = await client.put(
                f"{supabase_url}/auth/v1/admin/users/{user_id}",
                headers={
                    "Authorization": f"Bearer {service_role_key}",
                    "apikey": service_role_key,
                    "Content-Type": "application/json",
                },
                json={
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {"account_type": account_type},
                },
            )
    except httpx.HTTPError as exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is temporarily unavailable",
        ) from exception

    if response.status_code != status.HTTP_200_OK:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication service rejected the account approval",
        )


@router.post("/admin/create-user")
async def create_user_as_admin(
    payload: AdminAccountCreatePayload,
    _admin: Annotated[dict[str, Any], Depends(require_supabase_admin)],
):
    email = payload.email.strip().lower()
    if not email or "@" not in email:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A valid user email is required",
        )
    existing_user = _find_user_status(email)
    if existing_user is not None and existing_user[1]:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User already exists",
        )

    account_type = "vendor" if payload.account_type == "vendor" else "personal"
    temporary_password = _generate_temporary_password()
    if existing_user is None:
        await _create_user(email, temporary_password, account_type)
    else:
        await _approve_pending_user(
            existing_user[0], temporary_password, account_type
        )
    return {
        "email": email,
        "account_type": account_type,
        "temporary_password": temporary_password,
    }


@router.post("/admin/reset-password")
async def reset_user_password_as_admin(
    payload: AdminPasswordResetPayload,
    _admin: Annotated[dict[str, Any], Depends(require_supabase_admin)],
):
    email = payload.email.strip().lower()
    if not email or "@" not in email:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A valid user email is required",
        )

    user_id = _find_user_id(email)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    temporary_password = _generate_temporary_password()
    await _update_user_password(user_id, temporary_password)
    return {
        "email": email,
        "temporary_password": temporary_password,
    }
