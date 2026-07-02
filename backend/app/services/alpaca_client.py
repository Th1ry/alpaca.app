from __future__ import annotations

from typing import Any

import httpx

from app.config import Settings, get_settings

DATA_BASE = "https://data.alpaca.markets"


class AlpacaError(Exception):
    def __init__(self, status: int, message: str) -> None:
        self.status = status
        self.message = message
        super().__init__(message)


class AlpacaClient:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        headers = {
            "APCA-API-KEY-ID": self.settings.alpaca_api_key,
            "APCA-API-SECRET-KEY": self.settings.alpaca_api_secret,
            "Accept": "application/json",
        }
        self._trading = httpx.AsyncClient(
            base_url=self.settings.alpaca_base,
            headers=headers,
            timeout=25.0,
        )
        self._data = httpx.AsyncClient(
            base_url=DATA_BASE,
            headers=headers,
            timeout=25.0,
        )

    async def close(self) -> None:
        await self._trading.aclose()
        await self._data.aclose()

    async def trading_request(self, method: str, path: str, json: dict | None = None) -> Any:
        resp = await self._trading.request(method, path, json=json)
        return self._parse(resp)

    async def data_request(self, method: str, path: str) -> Any:
        resp = await self._data.request(method, path)
        return self._parse(resp)

    @staticmethod
    def _parse(resp: httpx.Response) -> Any:
        if resp.status_code >= 400:
            try:
                body = resp.json()
                msg = body.get("message") or body.get("error") or resp.text
            except Exception:
                msg = resp.text or f"HTTP {resp.status_code}"
            raise AlpacaError(resp.status_code, str(msg))
        if not resp.content:
            return {}
        return resp.json()


_client: AlpacaClient | None = None


def get_alpaca() -> AlpacaClient:
    global _client
    if _client is None:
        _client = AlpacaClient()
    return _client


async def shutdown_alpaca() -> None:
    global _client
    if _client is not None:
        await _client.close()
        _client = None
