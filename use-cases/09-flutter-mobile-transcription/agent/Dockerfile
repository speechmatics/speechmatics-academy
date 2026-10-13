# syntax=docker/dockerfile:1
# Same runtime family as LiveKit's current official Python starter.
FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim AS build
ENV PYTHONUNBUFFERED=1 UV_COMPILE_BYTECODE=1 \
    HF_HOME=/app/.cache/huggingface TORCH_HOME=/app/.cache/torch
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev
RUN uv run --no-sync --module livekit.agents download-files
COPY agent.py config.py token_server.py ./

FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim
ENV PYTHONUNBUFFERED=1 \
    HF_HOME=/app/.cache/huggingface TORCH_HOME=/app/.cache/torch
RUN adduser --disabled-password --gecos "" --home /app --shell /sbin/nologin --uid 10001 appuser
COPY --from=build --chown=appuser:appuser /app /app
WORKDIR /app
USER appuser
CMD ["uv", "run", "--no-sync", "agent.py", "start"]
