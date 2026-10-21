<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/LK_wordmark_darkbg.png">
  <source media="(prefers-color-scheme: light)" srcset="../logo/LK_wordmark_lightbg.png">
  <img alt="LiveKit" src="../logo/LK_wordmark_lightbg.png" width="300">
</picture>

# Telephony Voice Assistant - Twilio + LiveKit + Speechmatics

**Build an inbound phone assistant with Twilio, LiveKit SIP, and Speechmatics Speech to Text and Text to Speech.**

</div>

The application combines Speechmatics Speech to Text (STT), an OpenAI large language model (LLM), and Speechmatics Text to Speech (TTS). LiveKit's Speechmatics STT plugin uses **agent STT**, powered by **Linden 1**, on the Realtime API; LiveKit and Twilio handle the call transport.

## What You'll Learn

- How to integrate Speechmatics STT and TTS with LiveKit Agents for telephony
- Setting up Twilio Elastic SIP Trunking with LiveKit
- Handling inbound phone calls with LiveKit SIP
- Using LiveKit's agent framework for phone-based conversations
- Voice activity detection (VAD) to finalize user turns

## Prerequisites

- **Speechmatics API key**: Create one in the [Speechmatics portal](https://portal.speechmatics.com/)
- **OpenAI API key**: Get one from [platform.openai.com](https://platform.openai.com/)
- **LiveKit Cloud Account**: Get one from [cloud.livekit.io](https://cloud.livekit.io/)
- **Twilio Account**: Get one from [twilio.com](https://www.twilio.com/)
- **Twilio Phone Number**: Purchase a phone number in the Twilio Console
- **Python 3.10+** (Python 3.12 recommended)

## Quick Start

### Python

**Step 1: Create and activate a virtual environment**

**On Windows:**
```bash
cd python
python -m venv .venv
.venv\Scripts\activate
```

**On Mac/Linux:**
```bash
cd python
python3 -m venv .venv
source .venv/bin/activate
```

**Step 2: Install dependencies**

```bash
pip install -r requirements.txt
```

**Step 3: Configure your API keys**

```bash
cp ../.env.example .env
```

Open the `.env` file and add your API keys:

```
SPEECHMATICS_API_KEY=your_speechmatics_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_livekit_api_key_here
LIVEKIT_API_SECRET=your_livekit_api_secret_here
```

> [!IMPORTANT]
> **Why `.env`?** Never commit API keys to version control. The `.env` file keeps secrets out of your code.

**Step 4: Configure Twilio SIP Trunk**

See [Twilio + LiveKit SIP Setup](#twilio--livekit-sip-setup) below.

**Step 5: Run the agent**

```bash
python main.py dev
```

**Step 6: Call your Twilio number**

Call your Twilio phone number and start talking to Roxie!

## Architecture

```mermaid
flowchart LR
    subgraph Phone
        CALLER[Caller]
    end

    subgraph Twilio
        PSTN[PSTN Gateway]
        SIP[Elastic SIP Trunk]
    end

    subgraph LiveKit Cloud
        LKSIP[LiveKit SIP]
        ROOM[LiveKit Room]
    end

    subgraph Agent
        STT[Speechmatics STT]
        LLM[OpenAI LLM]
        TTS[Speechmatics TTS]
        VAD[Silero VAD]
    end

    CALLER <-->|Phone Call| PSTN
    PSTN <-->|SIP| SIP
    SIP <-->|SIP| LKSIP
    LKSIP <-->|WebRTC| ROOM
    ROOM --> STT
    STT --> LLM
    LLM --> TTS
    TTS --> ROOM
    VAD --> STT
```

## How It Works

### Pipeline Flow

1. **Incoming Call** - Caller dials your Twilio phone number
2. **SIP Routing** - Twilio routes call via SIP to LiveKit
3. **Room Connection** - LiveKit SIP creates a room participant for the caller
4. **Speech to Text** - Speechmatics transcribes the caller's speech
5. **LLM Processing** - OpenAI generates a response
6. **Text to Speech** - Speechmatics converts response to audio
7. **Audio Playback** - Audio streams back through LiveKit SIP to the caller

### Key Components

| Component | Description |
|-----------|-------------|
| **LiveKit Agents** | Framework for building real-time voice AI applications |
| **LiveKit SIP** | Bridges PSTN calls to LiveKit rooms via SIP |
| **Twilio Elastic SIP** | Routes phone calls to LiveKit's SIP endpoint |
| **Speechmatics STT** | Agent STT for the speech recognition stage |
| **OpenAI GPT-4o-mini** | Language model for generating responses |
| **Speechmatics TTS** | Converts the LLM response to speech |
| **Silero VAD** | Voice Activity Detection for turn-taking |

### Code Highlights

```python
from livekit.agents import AgentSession, Agent
from livekit.plugins import speechmatics, openai, silero

class VoiceAssistant(Agent):
    def __init__(self) -> None:
        super().__init__(instructions="You are Roxie, a hilarious standup comedian...")

async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()

    # The same Silero VAD drives the session and the STT's turn finalization
    # (passing `vad` into the STT forces EXTERNAL turn detection).
    vad = silero.VAD.load()

    session = AgentSession(
        stt=speechmatics.STT(vad=vad),
        llm=openai.LLM(model="gpt-4o-mini"),
        tts=speechmatics.TTS(voice="megan"),
        vad=vad,
    )

    await session.start(room=ctx.room, agent=VoiceAssistant())
    await session.generate_reply(instructions="Say hello...")
```

## Twilio + LiveKit SIP Setup

### Step 1: Create LiveKit Inbound Trunk

First, create a SIP trunk in LiveKit to receive calls:

1. Go to [LiveKit Cloud Console](https://cloud.livekit.io/)
2. Navigate to **Telephony Configuration** > **SIP Trunks**
3. Click **Create SIP Trunk**
4. Configure:
   - **Trunk name**: Give it a name (e.g., "Twilio Inbound")
   - **Trunk direction**: Select **Inbound**
   - **Numbers**: Enter your Twilio phone number (e.g., `+14155551234`)
   - **Allowed addresses**: Restrict incoming calls to the addresses used by your SIP provider; use [Twilio's current SIP trunking network requirements](https://www.twilio.com/docs/sip-trunking/ip-addresses)
5. Click **Create** and copy the **SIP URI** (e.g., `sip:xxxxx.sip.livekit.cloud`)

### Step 2: Create Twilio Elastic SIP Trunk

1. Go to [Twilio Console](https://console.twilio.com/)
2. Navigate to **Elastic SIP Trunking** > **Trunks**
3. Click **Create new SIP Trunk**
4. Give it a name (e.g., "LiveKit Voice Assistant")

### Step 3: Configure Twilio Origination (Inbound Calls)

Point Twilio to your LiveKit SIP endpoint:

1. In your Twilio SIP trunk, go to **Origination**
2. Add an **Origination URI**:
   - **Origination SIP URI**: Paste the LiveKit SIP URI from Step 1
   - **Priority**: 1
   - **Weight**: 1
   - **Enabled**: Yes
3. Save the configuration

### Step 4: Associate Phone Number in Twilio

1. In your Twilio SIP trunk, go to **Phone Numbers**
2. Click **Add a Phone Number**
3. Select your Twilio phone number
4. Save the configuration

### Step 5: Create LiveKit Dispatch Rule

Route incoming calls to your agent:

1. Go to [LiveKit Cloud Console](https://cloud.livekit.io/)
2. Navigate to **Telephony Configuration** > **Dispatch Rules**
3. Click **Create Dispatch Rule**
4. Configure:
   - **Trunk**: Select the inbound trunk you created in Step 1
   - **Rule Type**: Individual (creates a room per call)
   - **Room Prefix**: `call-` (or any prefix you prefer)
5. Save the configuration

## Customization

### Customize the Agent Prompt

Edit `assets/agent.md` to change the assistant's personality. The default configures Roxie as a standup comedian optimized for phone conversations.

### Enable noise cancellation

Enable Krisp on the **inbound SIP trunk**, following the [LiveKit inbound trunk guide](https://docs.livekit.io/telephony/accepting-calls/inbound-trunk/). In the trunk's JSON editor, set `krispEnabled` to `true`; the Python SDK field is `krisp_enabled`.

This setting filters the caller's audio before it reaches the room. It belongs to the inbound trunk, not the dispatch rule's `roomConfig`.

## Running Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Dev** | `python main.py dev` | Connects to LiveKit Cloud for testing |
| **Console** | `python main.py console` | Local testing with microphone (no phone) |
| **Production** | `python main.py start` | Production deployment |

## Comparison: LiveKit SIP vs Direct Twilio Media Streams

| Feature | LiveKit SIP (This Sample) | Direct Twilio (01-outbound-dialer) |
|---------|--------------------------|-------------------------------------|
| **Infrastructure** | LiveKit Cloud handles SIP | Your server handles WebSocket |
| **Scaling** | Built-in via LiveKit | Manual server scaling |
| **Audio Format** | Handled by LiveKit | Manual mulaw conversion |
| **Setup Complexity** | SIP trunk configuration | Webhook + ngrok setup |
| **Focus** | SIP routing and LiveKit-managed transport | Direct Media Streams handling |

## Troubleshooting

**Error: "Invalid API key"**
- Verify all API keys in your `.env` file
- Check each service's portal for key validity

**Calls not connecting**
- Verify Twilio SIP trunk origination URI is correct
- Check LiveKit dispatch rules are configured
- Ensure LiveKit API credentials are valid

**Agent doesn't respond**
- Check OpenAI API key is valid
- Verify you have API credits available

**No audio heard by caller**
- Check Speechmatics API key
- Verify TTS is generating audio in logs

## Next Steps

- **[Simple Voice Assistant - LiveKit](../01-simple-voice-assistant/)** - WebRTC-based voice assistant
- **[Outbound Dialer - Direct Twilio](../../twilio/01-outbound-dialer/)** - Compare with direct Twilio integration

## Resources

- [LiveKit SIP Documentation](https://docs.livekit.io/sip/)
- [LiveKit Agents Documentation](https://docs.livekit.io/agents/)
- [Twilio Elastic SIP Trunking](https://www.twilio.com/docs/sip-trunking)
- [Configuring Twilio Trunk for LiveKit](https://docs.livekit.io/sip/quickstarts/configuring-twilio-trunk/)
- [Speechmatics API Docs](https://docs.speechmatics.com/)
- [OpenAI API Docs](https://platform.openai.com/docs)

---

## Feedback

Help us improve this guide:
- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/orgs/speechmatics/discussions/categories/academy)

---

**Time to Complete**: 30 minutes
**Difficulty**: Advanced
**API Mode**: Realtime — agent STT; Text to Speech
**Integration**: LiveKit + Twilio SIP

[Back to Integrations](../../) | [Back to Academy](../../../README.md)
