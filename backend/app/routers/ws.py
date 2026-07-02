from __future__ import annotations

import asyncio
import json
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.config import get_settings
from app.services.trading import get_account, get_positions, get_quotes_batch

router = APIRouter()


class ConnectionManager:
    def __init__(self) -> None:
        self.active: list[WebSocket] = []
        self.subscriptions: dict[WebSocket, set[str]] = {}
        self.portfolio_watchers: set[WebSocket] = set()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        self.active.append(ws)
        self.subscriptions[ws] = set()

    def disconnect(self, ws: WebSocket) -> None:
        if ws in self.active:
            self.active.remove(ws)
        self.subscriptions.pop(ws, None)
        self.portfolio_watchers.discard(ws)

    def subscribe(self, ws: WebSocket, symbols: list[str]) -> None:
        self.subscriptions[ws] = {s.upper() for s in symbols if s}

    def subscribe_portfolio(self, ws: WebSocket) -> None:
        self.portfolio_watchers.add(ws)

    async def broadcast_quotes(self, quotes: dict[str, Any]) -> None:
        dead: list[WebSocket] = []
        for ws in self.active:
            syms = self.subscriptions.get(ws, set())
            payload = {s: quotes[s] for s in syms if s in quotes}
            if not payload:
                continue
            try:
                await ws.send_json({"type": "quotes", "data": payload})
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)

    async def broadcast_portfolio(self, positions: list[Any], account: Any) -> None:
        if not self.portfolio_watchers:
            return
        dead: list[WebSocket] = []
        payload = {
            "type": "portfolio",
            "positions": [p.model_dump() for p in positions],
            "account": account.model_dump(),
        }
        for ws in list(self.portfolio_watchers):
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


manager = ConnectionManager()
_quote_poll_task: asyncio.Task | None = None
_portfolio_poll_task: asyncio.Task | None = None


async def _quote_poller() -> None:
    settings = get_settings()
    interval = settings.poll_interval_sec
    while True:
        symbols: set[str] = set()
        for syms in manager.subscriptions.values():
            symbols |= syms
        if symbols and settings.alpaca_configured:
            try:
                quotes = await get_quotes_batch(
                    list(symbols),
                    settings.alpaca_data_feed,
                    settings.alpaca_option_feed,
                )
                if quotes:
                    await manager.broadcast_quotes(
                        {k: v.model_dump() for k, v in quotes.items()}
                    )
            except Exception:
                pass
        await asyncio.sleep(interval)


async def _portfolio_poller() -> None:
    settings = get_settings()
    interval = settings.poll_interval_sec
    while True:
        if manager.portfolio_watchers and settings.alpaca_configured:
            try:
                positions = await get_positions()
                account = await get_account()
                await manager.broadcast_portfolio(positions, account)
            except Exception:
                pass
        await asyncio.sleep(interval)


def start_pollers() -> None:
    global _quote_poll_task, _portfolio_poll_task
    if _quote_poll_task is None:
        _quote_poll_task = asyncio.create_task(_quote_poller())
    if _portfolio_poll_task is None:
        _portfolio_poll_task = asyncio.create_task(_portfolio_poller())


@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket) -> None:
    await manager.connect(ws)
    start_pollers()
    try:
        while True:
            raw = await ws.receive_text()
            msg = json.loads(raw)
            action = msg.get("action")
            if action == "subscribe":
                manager.subscribe(ws, msg.get("symbols") or [])
                await ws.send_json(
                    {"type": "subscribed", "symbols": list(manager.subscriptions[ws])}
                )
            elif action == "subscribe_portfolio":
                manager.subscribe_portfolio(ws)
                await ws.send_json({"type": "subscribed_portfolio"})
            elif action == "ping":
                await ws.send_json({"type": "pong"})
    except WebSocketDisconnect:
        manager.disconnect(ws)
