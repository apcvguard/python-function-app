"""Business logic kept free of the Azure SDK so it is easy to unit test."""
import os
from typing import Optional, Tuple


def build_greeting(name: Optional[str]) -> Tuple[int, dict]:
    if not name or not str(name).strip():
        return 400, {"error": "Pass a 'name' in the query string or JSON body."}
    clean = str(name).strip()[:100]
    return 200, {"message": f"Hello, {clean}!"}


def health_payload() -> dict:
    return {
        "status": "ok",
        "version": os.getenv("APP_VERSION", "local"),
        "environment": os.getenv("APP_ENV", "local"),
    }
