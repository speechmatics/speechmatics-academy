# EveryVoice LiveKit agent

The EveryVoice **Agent** screen connects to this named voice agent through LiveKit.
Home LIVE and batch transcription use their existing services.

The worker uses LiveKit Inference for Speechmatics `speechmatics/linden-1` STT,
`openai/gpt-4.1-mini`, and Cartesia `cartesia/sonic-3` TTS. The server controls the
language, LLM, voice, and base instructions through environment variables. No
separate provider API keys are needed. Speechmatics TTS is currently a separate
provider plugin, so it is deliberately not used in this native Inference pipeline.

## Local verification

Python 3.12–3.14 and uv are supported; the Cloud image uses Python 3.14.
`uv.lock` pins the resolved dependencies, including LiveKit Agents 1.8.4 and
LiveKit API 1.2.1.

```sh
uv sync --locked
uv run pytest -q
uv run ruff check .
uv run python agent.py --help
```

The tests verify JWT signatures and grants without real credentials or model calls.
The actual SDK model objects are instantiated, with only LLM connection prewarm
disabled in the test. No cloud session is started by the suite.

## Hosted development token server

For testing the phone anywhere with internet access, enable **Development token
server** in the **speechmatics** project's LiveKit settings. Copy its server ID
into EveryVoice's **Agent > Connection setup > LiveKit hosted (development)**,
or supply it as the `LIVEKIT_TOKEN_SERVER_ID` build define. Keep the dispatch
name `everyvoice-agent`. The Cloud worker and its models do not need redeployment
for this client authentication change.

This route uses LiveKit's HTTPS development endpoint directly. The app does not
contact `token_server.py`, send its Bearer token, or require USB forwarding.
The development server supports named dispatch and the per-session personality
metadata already understood by the worker.

LiveKit's development server allows unrestricted token requests by anyone who
has its ID. The validation, authentication, and room restrictions documented
below describe our optional custom token service; they do not protect the hosted
development endpoint. Use an authenticated custom HTTPS endpoint for production.

## Optional local token service over USB

The token issuer runs locally while the worker runs in LiveKit Cloud. These are
separate processes: deploying the Cloud worker does **not** publish an HTTP token
endpoint.

1. Copy `.env.example` to the ignored `.env.local`. Set the selected project's
   `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` securely. Set
   `EVERYVOICE_APP_TOKEN` to a long random value; enter that value in the phone's
   Agent setup. The issuer will return 503 until its configuration is present.
2. Start the token service, bound to localhost only:

   ```sh
   uv run python token_server.py
   ```

   If the environment file is stored outside the build directory instead, use:

   ```sh
   uv run uvicorn token_server:app --host 127.0.0.1 --port 8000 --env-file /absolute/path/to/.env.local
   ```

3. With the Android phone connected through USB debugging, run:

   ```sh
   adb reverse tcp:8000 tcp:8000
   ```

4. In the **debug** app's Agent setup, set the endpoint to
   `http://127.0.0.1:8000/token`, the access token to `EVERYVOICE_APP_TOKEN`, and
   agent name to `everyvoice-agent`. Android debug network policy must allow
   this loopback HTTP URL. No public tunnel is needed.
5. Confirm the matching Cloud worker is ready, then start the Agent conversation.
   Remove the USB mapping when finished with `adb reverse --remove tcp:8000`.

`GET /health` returns only `{"status":"ok"}`. It reports that the HTTP service is
running, not whether Cloud credentials, dispatch, or the model pipeline work.

## Token contract

`POST /token` requires `Authorization: Bearer <EVERYVOICE_APP_TOKEN>` and JSON:

```json
{
  "room_config": {
    "agents": [{
      "agent_name": "everyvoice-agent",
      "metadata": "{\"personality\":\"Be warm and concise.\"}"
    }]
  }
}
```

An empty object is accepted using the configured agent and default personality.
Personality is the only metadata property and is limited to 12,000 characters.
The worker repeats validation when reading dispatch metadata. Standard SDK
participant/room fields may be omitted or null; non-null values, different agent
names, deployment overrides, extra fields, and multiple agents are rejected.

The issuer creates a unique opaque room and participant for each request. Its
10-minute JWT permits joining that room, publishing microphone/data, and
subscribing to the agent. It carries explicit named-agent dispatch. It grants
no room administrator, recording, room-list, SIP, or model-inference access.
The response is `201 {"server_url":"...","participant_token":"..."}`.
Authentication comparisons are constant-time and invalid requests do not echo
their contents. Request bodies are limited to 64 KiB.

The access token is for this personal first-run setup. For a multi-user public
deployment, integrate the issuer with application user authentication and
request quotas. Keep LiveKit signing credentials on the server; never put them
in Flutter or build-time app defines. Any later public token host must use HTTPS.

## Cloud deployment

Target the verified **speechmatics** project (ID `p_39rz86ejydw`), with URL
`wss://speechmatics-58s7pbzh.livekit.cloud`. Keep the existing `Speechmatics_AI`
agent (`CA_cPiiPuZaz4aT`) unchanged. The new application dispatch name is
`everyvoice-agent`, which is distinct from a Cloud agent ID.

The deployed EveryVoice agent is `CA_7cctRyen6Vqg`. Its `livekit.toml` is included
for subsequent updates; use `lk agent deploy` from this directory with the
authenticated CLI targeting **speechmatics**. Do not run `lk agent create` for
routine updates or substitute the existing `Speechmatics_AI` agent ID.

The Docker build installs the locked dependencies, prepares SDK assets, and runs
as a non-root user. It copies only the three Python runtime modules; local
environment files are excluded. The supplied `livekit.toml.example` is a
reference for a separate future deployment, not a deployable configuration.

LiveKit Cloud injects `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET`
for the worker. Set optional `EVERYVOICE_*` model/personality settings only if
needed. `EVERYVOICE_APP_TOKEN` is only needed by the local token service and does
not need to be uploaded to the Cloud worker. After creation, confirm the returned
agent status and dispatch name before testing. Never interpret a successful
image upload as proof that a voice conversation works.

For later updates to this newly created agent, use its generated `livekit.toml`
with `lk agent deploy`; use `lk agent status` and `lk agent logs` for verification.

## Official references (checked 2026-10-05)

- [Speechmatics Inference STT](https://docs.livekit.io/agents/models/stt/speechmatics/)
- [Cartesia Inference TTS](https://docs.livekit.io/agents/models/tts/cartesia/)
- [Inference LLM models](https://docs.livekit.io/agents/models/llm/)
- [Agent server quickstart](https://docs.livekit.io/agents/start/voice-ai/)
- [Turn handling](https://docs.livekit.io/agents/logic/turns/)
- [Authenticated token endpoint](https://docs.livekit.io/frontends/build/authentication/endpoint/)
- [Agent dispatch](https://docs.livekit.io/agents/server/agent-dispatch/)
- [Cloud deployment](https://docs.livekit.io/deploy/agents/quickstart/)
- [Deployment configuration](https://docs.livekit.io/deploy/agents/managing-deployments/)
- [Official Python Dockerfile](https://github.com/livekit-examples/agent-starter-python/blob/main/Dockerfile)
