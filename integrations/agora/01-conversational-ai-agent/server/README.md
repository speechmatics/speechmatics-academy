# Agora Agent Service

Agora Conversational AI Agent service built with FastAPI.

## Quick Start

Use the repo-root [README.md](../README.md) for the normal full-stack local flow. This document is for working on the Python backend module directly.

Recommended from the repo root.

Repo setup:

```bash
bun run setup
```

Agora credentials:

```bash
agora project env write server/.env --template standard
bun run setup:env
# Set SPEECHMATICS_API_KEY in server/.env.
```

Run the app:

```bash
bun run dev
```

This assumes the Agora CLI is installed and logged in. The command uses the project selected in your Agora CLI context, which is usually your default account project.

If you are not using the Agora CLI, create the env file manually and fill in your project values:

```bash
cp server/.env.example server/.env      # cmd.exe: copy server\.env.example server\.env
```

Or let the project do it for you on any platform - `bun run setup:env` creates
`server/.env` from the template and normalises the key layout.

From `server/`:

### 1. Configure Environment

Backend-only Agora CLI env write:

```bash
agora project env write .env
python3 scripts/setup_env.py      # Windows: python scripts\setup_env.py
```

Manual fallback:

```bash
cp .env.example .env      # cmd.exe: copy .env.example .env
```

`.env.example` is the committed reference template. `.env` is the only local
dotenv file and is gitignored. If you are not using the Agora CLI, edit `.env`
and fill in your credentials:
- `AGORA_APP_ID` - Your Agora App ID (Required)
- `AGORA_APP_CERTIFICATE` - Your Agora App Certificate (Required)
- `SPEECHMATICS_API_KEY` - Your Speechmatics API key (Required)

If you still need to authenticate with the CLI:

```bash
agora login
```

To select a specific existing project before writing env values:

```bash
agora project use <project-id-or-name>
agora project env write .env
python3 scripts/setup_env.py      # Windows: python scripts\setup_env.py
```

To create a new project instead of using your default project:

```bash
agora project create my-first-voice-agent --feature rtc --feature convoai
agora project use my-first-voice-agent
agora project env write .env
python3 scripts/setup_env.py      # Windows: python scripts\setup_env.py
```

The setup script preserves configured values, adds the Speechmatics key
placeholder if the CLI rewrote the file, and migrates legacy `APP_ID` /
`APP_CERTIFICATE` names to `AGORA_APP_ID` / `AGORA_APP_CERTIFICATE`. Validate
the result from the repo root with `bun run doctor:local`.

For deployment, set these variables through the host, container, or secret
manager. The process environment takes precedence; do not ship a production
`.env` file.

**Note**: The service uses Token007 authentication generated from `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE`. Its pipeline is `SpeechmaticsSTT` + managed `OpenAI` (`gpt-4o-mini`) + managed `MiniMaxTTS` (`speech_2_6_turbo` / `English_captivating_female1`). The FastAPI sample uses `AsyncAgora` so the request path remains non-blocking.

### 2. Install Dependencies

**Option A: Using Virtual Environment (Recommended)**

**On Windows:**
```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements-dev.txt
```

**On Mac/Linux:**
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt
```

> [!TIP]
> From the repo root, `bun run setup:backend` does all of this for you on
> either platform, and `bun run backend` starts the service without
> activating anything - activation cannot be scripted portably, so the
> project never relies on it.

**Option B: Global Installation (Not Recommended)**
```bash
pip install -r requirements.txt
```

### 3. Start Service

```bash
# If using virtual environment, make sure it's activated first
python src/server.py
```

> [!TIP]
> `bun run backend` from the repo root does this without activation, and picks
> the right interpreter on either platform.

The service will start on port 8000 (or the port specified in `.env`).

## How This Fits The Repo

- Full-stack local development: run `bun run dev` from the repo root. The browser still calls Next `/api/*`, and Next rewrites those requests to this FastAPI service.
- Module-local backend work: use the commands in this README when you only need to run or inspect the Python service itself.
- Deployment: this Python service is required because the web app only forwards API requests through `AGENT_BACKEND_URL`.

### 4. Test API

> [!NOTE]
> The `curl` examples below assume a POSIX shell. In PowerShell use
> `Invoke-RestMethod`, for example:
> `Invoke-RestMethod -Method Post -Uri http://localhost:8000/startAgent -ContentType application/json -Body '{"channelName":"test_channel","rtcUid":123456,"userUid":789012}'`

```bash
# Test config generation
curl http://localhost:8000/get_config

# Test agent start
curl -X POST http://localhost:8000/startAgent \
  -H "Content-Type: application/json" \
  -d '{"channelName": "test_channel", "rtcUid": 123456, "userUid": 789012}'

# Test agent stop (use agent_id from start response)
curl -X POST http://localhost:8000/stopAgent \
  -H "Content-Type: application/json" \
  -d '{"agentId": "your_agent_id"}'
```

## API Endpoints

- `GET /get_config` - Generate connection configuration
- `POST /startAgent` - Start an agent
- `POST /stopAgent` - Stop an agent

`/get_config` now issues one-hour RTC plus RTM tokens. The web client renews both before expiry, matching the reference Next.js session model.

The repo-level `bun run verify:local:fastapi` check exercises this FastAPI app through the Next proxy path, but it swaps in a fake agent implementation so route wiring can be verified without depending on a live agent start.

## Requirements

- Python >= 3.10
- Dependencies listed in `requirements.txt`

## SDK

This project uses `agora-agents` (import `agora_agent`):
- Version `2.6.1` is pinned in `requirements.txt`.
- Package: `agora_agent`
- Agent builder: `agora_agent.agentkit.Agent` with fluent `.with_llm()` / `.with_tts()` / `.with_stt()` API
- Vendors: `SpeechmaticsSTT`, `OpenAI`, `MiniMaxTTS` from `agora_agent.agentkit.vendors`
- Token: `agora_agent.agentkit.token.generate_convo_ai_token`
