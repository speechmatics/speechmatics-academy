# Agora Conversational AI Demo — Architecture

This quickstart keeps the web UI and backend responsibilities separate. The Next.js app owns the browser-facing `/api/*` URLs, and `next.config.ts` rewrites them to the Python FastAPI service that owns token generation and agent lifecycle.

## Python-Backed Request Flow

```
Browser
  ↓
Next.js app
  ↓
/api/* rewrites through AGENT_BACKEND_URL
  ↓
FastAPI service
  ↓
Agora Cloud Services
```

- `web` owns the browser UI and the `/api/*` entrypoints
- `server` owns the actual token generation and agent start/stop logic
- this is the mode used by `bun run dev`

## Shared Conversation Flow

### 1. Connection

```
Frontend: GET /api/get_config
  → Generate Token007 config for a user UID, agent UID, and channel
  → Frontend joins RTC and logs into RTM
```

### 2. Agent Start

```
Frontend: POST /api/startAgent { channelName, rtcUid, userUid }
  → Build agent session
  → Scope remote_uids to the requesting user
  → Start session and return agent_id
```

### 3. Conversation

```
User audio → RTC
  → Managed ASR, LLM, and TTS pipeline
  → Agent audio + RTM transcript events
  → UIKit transcript and visualizer in the web app
```

### 4. Agent Stop

```
Frontend: POST /api/stopAgent { agentId }
  → Stop session directly or through stateless fallback
  → Client cleans up RTC and RTM state
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/get_config` | GET | Generate connection config (Token007, channel, UIDs) |
| `/startAgent` | POST | Start the agent session |
| `/stopAgent` | POST | Stop the agent by `agent_id` |

Frontend calls these as `/api/*`. Next rewrites those calls to `AGENT_BACKEND_URL`; the Next app does not run token or AgentKit logic in-process.

## Authentication

Token007 (AccessToken2) is generated from `AGORA_APP_ID` + `AGORA_APP_CERTIFICATE`. `SPEECHMATICS_API_KEY` is used only for ASR and remains in the FastAPI process. The SDK handles Agora token generation and API auth internally.

## Detailed Documentation

- [README.md](./README.md) — Quick start, configuration, deployment
- [server/README.md](./server/README.md) — Python backend details
