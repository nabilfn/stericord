"""
Thin PostgREST client that forwards the caller's own Supabase session JWT.

This is the whole authorization story for this service: every query runs
under the *caller's* session, so Postgres RLS -- the same policies the web
and mobile apps are subject to -- decides what comes back. The reporting
service never uses a service-role key and never re-implements tenant
isolation or role checks itself; it only renders whatever the database
already agreed the caller may see.
"""

import os

import httpx
from fastapi import HTTPException

SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_ANON_KEY = os.environ["SUPABASE_ANON_KEY"]


class SupabaseClient:
    def __init__(self, access_token: str):
        self._headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

    async def select_one(self, table: str, filters: dict[str, str]) -> dict:
        rows = await self.select(table, filters)
        if not rows:
            raise HTTPException(status_code=404, detail=f"{table} not found or not accessible")
        return rows[0]

    async def select(
        self, table: str, filters: dict[str, str] | None = None, order: str | None = None
    ) -> list[dict]:
        params = dict(filters or {})
        if order:
            params["order"] = order
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{SUPABASE_URL}/rest/v1/{table}",
                headers=self._headers,
                params=params,
                timeout=30,
            )
        if response.status_code >= 400:
            raise HTTPException(status_code=response.status_code, detail=response.text)
        return response.json()

    async def rpc(self, function_name: str, args: dict) -> dict | list:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{SUPABASE_URL}/rest/v1/rpc/{function_name}",
                headers=self._headers,
                json=args,
                timeout=30,
            )
        if response.status_code >= 400:
            raise HTTPException(status_code=response.status_code, detail=response.text)
        return response.json()

    async def whoami(self) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{SUPABASE_URL}/auth/v1/user",
                headers=self._headers,
                timeout=30,
            )
        if response.status_code >= 400:
            raise HTTPException(status_code=401, detail="Invalid or expired session")
        return response.json()
