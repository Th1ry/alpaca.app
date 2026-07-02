from __future__ import annotations

import json
from pathlib import Path

_STORE = Path(__file__).resolve().parents[2] / "data" / "dismissed_positions.json"
_dismissed: set[str] | None = None


def _load() -> set[str]:
    global _dismissed
    if _dismissed is not None:
        return _dismissed
    _dismissed = set()
    if _STORE.exists():
        try:
            raw = json.loads(_STORE.read_text(encoding="utf-8"))
            if isinstance(raw, list):
                _dismissed = {str(s).upper() for s in raw if s}
        except Exception:
            _dismissed = set()
    return _dismissed


def _save() -> None:
    syms = sorted(_load())
    _STORE.parent.mkdir(parents=True, exist_ok=True)
    _STORE.write_text(json.dumps(syms, indent=2), encoding="utf-8")


def get_dismissed_symbols() -> set[str]:
    return set(_load())


def dismiss_symbol(symbol: str) -> None:
    sym = symbol.upper().strip()
    if not sym:
        return
    _load().add(sym)
    _save()


def undismiss_symbol(symbol: str) -> None:
    sym = symbol.upper().strip()
    _load().discard(sym)
    _save()
