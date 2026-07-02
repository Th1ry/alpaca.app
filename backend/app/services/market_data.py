from __future__ import annotations

from datetime import datetime

from app.models.schemas import NewsItem
from app.services.alpaca_client import get_alpaca

_assets_cache: list[dict] | None = None

# Common Chinese aliases for US tickers.
CN_ALIASES: dict[str, str] = {
    "英伟达": "NVDA",
    "苹果": "AAPL",
    "特斯拉": "TSLA",
    "微软": "MSFT",
    "谷歌": "GOOGL",
    "亚马逊": "AMZN",
    "脸书": "META",
    "meta": "META",
    "奈飞": "NFLX",
    "英特尔": "INTC",
    "高通": "QCOM",
    "甲骨文": "ORCL",
    "波音": "BA",
    "迪士尼": "DIS",
    "摩根大通": "JPM",
    "伯克希尔": "BRK.B",
    "拼多多": "PDD",
    "阿里巴巴": "BABA",
    "京东": "JD",
    "百度": "BIDU",
    "蔚来": "NIO",
    "小鹏": "XPEV",
    "理想": "LI",
}


def _resolve_alias(query: str) -> str | None:
    q = query.strip()
    if not q:
        return None
    upper = q.upper()
    if upper in {v.upper() for v in CN_ALIASES.values()}:
        return upper
    if q in CN_ALIASES:
        return CN_ALIASES[q]
    q_lower = q.lower()
    for cn, sym in CN_ALIASES.items():
        if cn in q or q in cn or cn.lower() in q_lower:
            return sym
    return None


async def _load_assets() -> list[dict]:
    global _assets_cache
    if _assets_cache is not None:
        return _assets_cache
    client = get_alpaca()
    data = await client.trading_request("GET", "/v2/assets?status=active&asset_class=us_equity")
    _assets_cache = data if isinstance(data, list) else []
    return _assets_cache


async def search_symbols(query: str) -> list:
    from app.models.schemas import SearchResult

    q = query.strip()
    if not q:
        return []

    alias = _resolve_alias(q)
    if alias:
        try:
            client = get_alpaca()
            asset = await client.trading_request("GET", f"/v2/assets/{alias}")
            if asset.get("tradable"):
                return [
                    SearchResult(symbol=asset["symbol"], name=asset.get("name") or alias)
                ]
        except Exception:
            pass

    q_upper = q.upper()
    try:
        client = get_alpaca()
        asset = await client.trading_request("GET", f"/v2/assets/{q_upper}")
        if asset.get("tradable"):
            return [SearchResult(symbol=asset["symbol"], name=asset.get("name") or q_upper)]
    except Exception:
        pass

    assets = await _load_assets()
    out: list[SearchResult] = []
    q_lower = q.lower()
    for a in assets:
        sym = a.get("symbol") or ""
        name = a.get("name") or sym
        name_lower = name.lower()
        if (
            q_upper in sym
            or sym.startswith(q_upper)
            or q_lower in name_lower
            or q_upper in name.upper()
        ):
            out.append(SearchResult(symbol=sym, name=name))
            if len(out) >= 12:
                break
    return out


async def get_news(limit: int = 15, symbols: str | None = None) -> list[NewsItem]:
    client = get_alpaca()
    path = f"/v1beta1/news?limit={limit}&sort=desc"
    if symbols:
        path += f"&symbols={symbols}"
    data = await client.data_request("GET", path)
    raw = data.get("news") if isinstance(data, dict) else data
    if not isinstance(raw, list):
        return []

    items: list[NewsItem] = []
    for n in raw:
        created = n.get("created_at") or ""
        ts = 0
        if created:
            try:
                ts = int(datetime.fromisoformat(created.replace("Z", "+00:00")).timestamp())
            except Exception:
                ts = 0
        syms = n.get("symbols") or []
        items.append(
            NewsItem(
                id=str(n.get("id") or ""),
                headline=n.get("headline") or "",
                source=n.get("source") or n.get("author") or "",
                url=n.get("url") or "",
                created_at=ts,
                symbols=syms if isinstance(syms, list) else [],
            )
        )
    return items
