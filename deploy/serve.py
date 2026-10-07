"""
Container entrypoint for the self-hosted API image (deploy/api.Dockerfile).

The image's code is read-only, so settings written from the UI (LLM provider,
sources) must land on a mounted volume. This points every pydantic-settings
class at ``JOB_SENTINEL_CONFIG_FILE`` (default ``/config/.env``) before the API
is imported, then serves it with uvicorn.
"""

from __future__ import annotations

import os

CONFIG_FILE = os.environ.get("JOB_SENTINEL_CONFIG_FILE", "/config/.env")


def main() -> None:
    import uvicorn
    from dotenv import dotenv_values
    from pydantic_settings import BaseSettings

    from job_sentinel.config import settings

    settings._ENV_FILE = CONFIG_FILE
    for value in vars(settings).values():
        is_settings = isinstance(value, type) and issubclass(value, BaseSettings)
        if is_settings and value is not BaseSettings:
            value.model_config["env_file"] = CONFIG_FILE

    # The API reads AUTH_MODE from the process environment, not from Settings.
    os.environ.setdefault("AUTH_MODE", dotenv_values(CONFIG_FILE).get("AUTH_MODE") or "off")

    from job_sentinel.api.app import app

    # Binding all interfaces is the point inside a container; the host decides exposure.
    uvicorn.run(app, host="0.0.0.0", port=8000, proxy_headers=True, forwarded_allow_ips="*")  # noqa: S104


if __name__ == "__main__":
    main()
