#!/usr/bin/env python3
"""
Outbound Dialer - Make your AI assistant call any phone number.
"""

import asyncio
import audioop  # pip install audioop-lts for Python 3.13+
import base64
import json
import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import Response
from openai import AsyncOpenAI
from elevenlabs import AsyncElevenLabs
from speechmatics.voice import VoiceAgentClient, VoiceAgentConfigPreset, AgentServerMessageType
from twilio.rest import Client as TwilioClient
from twilio.twiml.voice_response import VoiceResponse
import uvicorn

load_dotenv()

app = FastAPI()

# =============================================================================
# Configuration
# =============================================================================

SPEECHMATICS_API_KEY = os.getenv("SPEECHMATICS_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")

# ElevenLabs voice - "Rachel" is a natural conversational voice
ELEVENLABS_VOICE_ID = "21m00Tcm4TlvDq8ikWAM"

# Load the assistant's personality from assets/agent.md
AGENT_PROMPT_FILE = Path(__file__).parent.parent / "assets" / "agent.md"
SYSTEM_PROMPT = AGENT_PROMPT_FILE.read_text() if AGENT_PROMPT_FILE.exists() else "You are a helpful assistant."

# Webhook URL (set dynamically when /dial is called)
WEBHOOK_BASE_URL = None

# Speechmatics Voice Agent preset
# - "low_latency": optimized for fast turn detection
# - overlay_json: override audio format for Twilio's mulaw 8kHz
SPEECHMATICS_PRESET = "low_latency"


# =============================================================================
# Audio Conversion
# =============================================================================

def pcm_to_mulaw(pcm_16khz: bytes) -> str:
    """
    Convert PCM audio to Twilio's required format.

    Twilio expects: mulaw encoded, 8kHz sample rate, base64 encoded
    ElevenLabs outputs: PCM 16-bit, 16kHz sample rate

    Steps:
    1. Resample 16kHz -> 8kHz (halve the sample rate)
    2. Convert linear PCM -> mulaw (telephone audio compression)
    3. Base64 encode for JSON transport
    """
    resampled = audioop.ratecv(pcm_16khz, 2, 1, 16000, 8000, None)[0]
    mulaw = audioop.lin2ulaw(resampled, 2)
    return base64.b64encode(mulaw).decode()


# =============================================================================
# Voice Assistant Logic
# =============================================================================

async def run_voice_assistant(twilio_ws: WebSocket, stream_sid: str):
    """
    Main voice assistant handler for a single call.

    Manages:
    - Speechmatics STT (speech-to-text with turn detection)
    - OpenAI LLM (conversation logic)
    - ElevenLabs TTS (text-to-speech, streamed for low latency)
    """
    openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY)
    elevenlabs_client = AsyncElevenLabs(api_key=ELEVENLABS_API_KEY)

    conversation_history = []  # Stores the full conversation for context
    current_turn_segments = []  # Accumulates speech segments until turn ends
    is_connected = True

    # -------------------------------------------------------------------------
    # Audio Output
    # -------------------------------------------------------------------------

    async def send_audio(payload: str):
        """Send a single audio chunk to Twilio."""
        if is_connected:
            await twilio_ws.send_json({
                "event": "media",
                "streamSid": stream_sid,
                "media": {"payload": payload}
            })

    async def speak(text: str):
        """
        Stream TTS audio to Twilio using ElevenLabs.

        Why streaming? Audio starts playing as soon as the first chunk arrives,
        rather than waiting for the entire response to generate.

        Chunk size: 640 bytes = 20ms of audio at 16kHz 16-bit
        (16000 samples/sec * 2 bytes/sample * 0.02 sec = 640 bytes)
        """
        if not is_connected:
            return

        audio_stream = elevenlabs_client.text_to_speech.stream(
            text=text,
            voice_id=ELEVENLABS_VOICE_ID,
            model_id="eleven_turbo_v2_5",
            output_format="pcm_16000",
        )

        pcm_buffer = b""
        async for chunk in audio_stream:
            if not is_connected:
                break
            pcm_buffer += chunk

            # Send 20ms chunks as they arrive for smooth playback
            while len(pcm_buffer) >= 640:
                await send_audio(pcm_to_mulaw(pcm_buffer[:640]))
                pcm_buffer = pcm_buffer[640:]
                await asyncio.sleep(0.02)  # Pace to match real-time

        # Send any remaining audio
        if pcm_buffer and is_connected:
            await send_audio(pcm_to_mulaw(pcm_buffer))

    # -------------------------------------------------------------------------
    # LLM Response Generation
    # -------------------------------------------------------------------------

    async def generate_response(user_input: str):
        """Generate and speak an LLM response."""
        if not is_connected:
            return

        conversation_history.append({"role": "user", "content": user_input})

        # Stream the LLM response for faster time-to-first-token
        stream = await openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "system", "content": SYSTEM_PROMPT}, *conversation_history],
            max_tokens=150,
            stream=True,
        )

        response = ""
        async for chunk in stream:
            if chunk.choices[0].delta.content:
                response += chunk.choices[0].delta.content

        if response:
            conversation_history.append({"role": "assistant", "content": response})
            print(f"[Assistant] {response}")
            await speak(response)

    # -------------------------------------------------------------------------
    # Speechmatics STT Setup
    # -------------------------------------------------------------------------

    # Load preset and override audio format for Twilio
    config = VoiceAgentConfigPreset.load(
        SPEECHMATICS_PRESET,
        overlay_json=json.dumps({"audio_encoding": "mulaw", "sample_rate": 8000})
    )
    client = VoiceAgentClient(api_key=SPEECHMATICS_API_KEY, config=config)

    @client.on(AgentServerMessageType.ADD_SEGMENT)
    def on_segment(message):
        """Called when Speechmatics recognizes speech."""
        for segment in message.get("segments", []):
            text = segment.get("text", "")
            if text:
                print(f"[User] {text}")
                current_turn_segments.append(text)

    @client.on(AgentServerMessageType.END_OF_TURN)
    def on_end_of_turn(message):
        """Called when user stops speaking - time to respond."""
        if current_turn_segments:
            user_input = " ".join(current_turn_segments)
            current_turn_segments.clear()
            asyncio.create_task(generate_response(user_input))

    # Connect to Speechmatics and greet the user
    await client.connect()
    await speak("Hello! This is your AI assistant calling. How can I help you today?")

    def disconnect():
        nonlocal is_connected
        is_connected = False

    return client, disconnect


# =============================================================================
# HTTP Endpoints
# =============================================================================

@app.get("/")
async def index():
    """Health check endpoint."""
    return {"status": "running", "service": "Outbound Dialer"}


@app.post("/dial")
async def dial(request: Request):
    """
    Initiate an outbound call.

    POST /dial
    Body: {"to": "+14155551234"}

    This calls the Twilio REST API to start the call.
    When answered, Twilio will request /twiml for instructions.
    """
    global WEBHOOK_BASE_URL

    # Determine webhook URL from request headers
    host = request.headers.get("host", "localhost:5000")
    protocol = "https" if "ngrok" in host else "http"
    WEBHOOK_BASE_URL = f"{protocol}://{host}"

    body = await request.json()
    to_number = body.get("to")

    if not to_number:
        return {"error": "Missing 'to' phone number"}, 400

    # Initiate the outbound call via Twilio REST API
    twilio_client = TwilioClient(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
    call = twilio_client.calls.create(
        to=to_number,
        from_=TWILIO_PHONE_NUMBER,
        url=f"{WEBHOOK_BASE_URL}/twiml",  # Twilio fetches this when call connects
    )

    print(f"Calling {to_number} (SID: {call.sid})")

    return {
        "success": True,
        "call_sid": call.sid,
        "to": to_number,
        "from": TWILIO_PHONE_NUMBER,
    }


@app.api_route("/twiml", methods=["GET", "POST"])
async def twiml(request: Request):
    """
    TwiML webhook - tells Twilio how to handle the call.

    When the call connects, Twilio requests this endpoint.
    We respond with TwiML that opens a Media Stream WebSocket.
    """
    host = request.headers.get("host", "localhost:5000")

    response = VoiceResponse()
    connect = response.connect()
    connect.stream(url=f"wss://{host}/media-stream")

    return Response(content=str(response), media_type="application/xml")


@app.websocket("/media-stream")
async def media_stream(websocket: WebSocket):
    """
    WebSocket endpoint for bidirectional audio streaming.

    Twilio sends audio from the caller here.
    We send assistant audio back through here.
    """
    await websocket.accept()
    client, disconnect = None, None

    try:
        while True:
            message = json.loads(await websocket.receive_text())
            event = message.get("event")

            if event == "start":
                # Call connected - start the voice assistant
                stream_sid = message["start"]["streamSid"]
                print(f"Call connected (Stream: {stream_sid})")
                client, disconnect = await run_voice_assistant(websocket, stream_sid)

            elif event == "media" and client:
                # Incoming audio from caller - send to Speechmatics
                audio = base64.b64decode(message["media"]["payload"])
                await client.send_audio(audio)

            elif event == "stop":
                print("Call ended")
                break

    finally:
        if disconnect:
            disconnect()
        if client:
            await client.disconnect()


# =============================================================================
# Entry Point
# =============================================================================

if __name__ == "__main__":
    print("Outbound Dialer")
    print("=" * 40)
    print("1. Start ngrok:  ngrok http 5000")
    print("2. Make a call:  python dial.py +1234567890 --server <ngrok-url>")
    print()
    uvicorn.run(app, host="0.0.0.0", port=5000)
