# VAPI Voice Assistant with Speechmatics STT
FROM python:3.12-slim-bookworm

WORKDIR /app

# Install dependencies. Copy requirements.txt first so this layer is cached
# until the dependencies actually change (source edits won't bust the cache).
COPY python/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY python/ .

CMD ["python", "main.py", "--help"]
