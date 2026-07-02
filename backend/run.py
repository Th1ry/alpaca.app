#!/usr/bin/env python3
import os
import uvicorn

from app.config import get_settings

if __name__ == "__main__":
    s = get_settings()
    reload = os.environ.get("DEV", "") == "1"
    uvicorn.run("app.main:app", host=s.host, port=s.port, reload=reload)
