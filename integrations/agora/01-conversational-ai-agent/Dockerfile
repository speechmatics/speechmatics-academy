# syntax=docker/dockerfile:1
FROM python:3.12-slim-bookworm AS runtime

# Run as a non-root user (created before any COPY so --chown can reference it).
RUN useradd --create-home --uid 10001 app
WORKDIR /app

# Python dependencies for the FastAPI backend (installed as root into the
# system site-packages, world-readable for the app user at runtime).
COPY server/requirements.txt /tmp/server-req.txt
RUN pip install --no-cache-dir -r /tmp/server-req.txt

# Backend source, owned by the runtime user.
COPY --chown=app:app server/src /app/server/src

# Drop privileges for the running process.
USER app

# server.py reads $PORT (default 8000) and binds 0.0.0.0.
EXPOSE 8000
CMD ["python", "/app/server/src/server.py"]
