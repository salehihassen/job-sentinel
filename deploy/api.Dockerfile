# Job Sentinel — self-hosted API image (FastAPI + Playwright + Tectonic).
#
# Unlike the root Dockerfile (the always-on bot), this serves the HTTP API the
# web UI consumes. Published to ghcr.io by .github/workflows/images.yml.
#
#   docker build -f deploy/api.Dockerfile -t job-sentinel-api .
#
# Mounts: /config (writable .env, see deploy/serve.py), /app/data, /app/logs.
# Runs as uid 1000 and works with a read-only root filesystem given tmpfs /tmp.
FROM mcr.microsoft.com/playwright/python:v1.60.0-jammy@sha256:aaa8048c7a7c414fab6ad809469eb35f13bbf5093038113eef851b3c4814ad77

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:0.11.21@sha256:ff07b86af50d4d9391d9daf4ff89ce427bc544f9aae87057e69a1cc0aa369946 /uv /uvx /bin/

# The base image ships Python 3.10; let uv provide 3.12 at a world-readable path.
ENV UV_PYTHON=3.12 UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python
COPY pyproject.toml uv.lock README.md ./
COPY src ./src
# Editable install keeps the package's repo-root-relative state paths (data/, logs/)
# resolving under /app, where the volumes are mounted.
RUN uv sync --locked --no-dev --extra web
ENV PATH="/app/.venv/bin:$PATH"

# The lockfile can pin Playwright newer than the base image's bundled browsers.
RUN playwright install chromium

# Tectonic renders résumé PDFs without a full TeX Live install.
ADD --checksum=sha256:8533d07f9ccbd7a65824b9e0459041bca34af1eb33daba48f59215593753a3b7 https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.17.0/tectonic-0.17.0-x86_64-unknown-linux-musl.tar.gz /tmp/tectonic.tar.gz
RUN tar -xzf /tmp/tectonic.tar.gz -C /usr/local/bin && rm /tmp/tectonic.tar.gz

COPY deploy/serve.py /app/deploy/serve.py
RUN mkdir -p /app/data /app/logs /config && chown -R 1000:1000 /app/data /app/logs /config

USER 1000:1000
EXPOSE 8000
ENTRYPOINT ["python", "/app/deploy/serve.py"]
