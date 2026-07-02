from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import api, ws
from app.services.alpaca_client import shutdown_alpaca


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await shutdown_alpaca()


def create_app() -> FastAPI:
    app = FastAPI(title="Alpaca Options API", version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(api.router)
    app.include_router(ws.router)
    return app


app = create_app()
