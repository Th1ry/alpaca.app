from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    alpaca_api_url: str = "https://paper-api.alpaca.markets"
    alpaca_api_key: str = ""
    alpaca_api_secret: str = ""
    alpaca_data_feed: str = "iex"
    alpaca_option_feed: str = "indicative"
    # Alpaca Basic: 200 market-data + 200 trading requests/min (independent).
    poll_interval_sec: float = 0.3
    host: str = "127.0.0.1"
    port: int = 8000

    @property
    def alpaca_base(self) -> str:
        base = self.alpaca_api_url.rstrip("/")
        if base.endswith("/v2"):
            base = base[:-3]
        return base

    @property
    def alpaca_configured(self) -> bool:
        return bool(self.alpaca_api_key and self.alpaca_api_secret)

    @property
    def is_paper(self) -> bool:
        return "paper" in self.alpaca_base


@lru_cache
def get_settings() -> Settings:
    return Settings()
