# VAPI Voice Assistant with Speechmatics STT
FROM python:3.12-slim-bookworm

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir vapi-server-sdk python-dotenv

COPY python/ .

CMD ["python", "main.py", "--help"]
