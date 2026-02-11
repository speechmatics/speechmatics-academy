"""Medical Assistant - FastAPI backend with WebSocket for real-time transcription"""
import asyncio
import json
import uuid
from datetime import datetime
from pathlib import Path
from contextlib import asynccontextmanager
from functools import lru_cache
from typing import Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic_settings import BaseSettings
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


class SessionState(BaseModel):
    """State of the current session"""
    session_id: str
    patient_name: Optional[str] = None
    started_at: Optional[datetime] = None
    is_recording: bool = False
    is_paused: bool = False


class Settings(BaseSettings):
    """Application settings from environment"""
    speechmatics_api_key: str = ""
    openai_api_key: str = ""
    host: str = "0.0.0.0"
    port: int = 7860

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()


# Import services
from backend.services.transcription import TranscriptionService, TranscriptionSession, DiarizedTranscript
from backend.services.extraction import (
    ExtractionService, MedicalFormData, SuggestionsService, AISuggestions,
    SpeakerRoleInference, SpeakerRole, DiarizedUtterance,
    SOAPService, SOAPNote, ICDCode
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    settings = get_settings()

    # Validate API keys on startup
    if not settings.speechmatics_api_key:
        print("WARNING: SPEECHMATICS_API_KEY not set")
    if not settings.openai_api_key:
        print("WARNING: OPENAI_API_KEY not set")

    yield


app = FastAPI(
    title="Medical Assistant",
    description="Bilingual Medical Transcription Assistant",
    version="0.1.0",
    lifespan=lifespan,
)


# Serve frontend static files
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/css", StaticFiles(directory=frontend_path / "css"), name="css")
    app.mount("/js", StaticFiles(directory=frontend_path / "js"), name="js")


@app.get("/")
async def serve_index():
    """Serve the main HTML page"""
    return FileResponse(frontend_path / "index.html")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    settings = get_settings()
    return {
        "status": "healthy",
        "speechmatics_configured": bool(settings.speechmatics_api_key),
        "openai_configured": bool(settings.openai_api_key),
    }


class TranscriptionManager:
    """Manages WebSocket connection and transcription session"""

    def __init__(self, websocket: WebSocket, language: str,
                 speaker_sensitivity: float = 0.7,
                 prefer_current_speaker: bool = True):
        self.websocket = websocket
        self.language = language
        self.speaker_sensitivity = speaker_sensitivity
        self.prefer_current_speaker = prefer_current_speaker
        self.settings = get_settings()

        # Session state
        self.session_state = SessionState(
            session_id=str(uuid.uuid4()),
            started_at=None,
            is_recording=False,
            is_paused=False
        )

        # Transcript management
        self.transcript_buffer: list[str] = []
        self.diarized_utterances: list[DiarizedUtterance] = []
        self.speaker_history: dict[str, SpeakerRole] = {}

        # Form and suggestions
        self.current_form_data = MedicalFormData()
        self.current_suggestions = AISuggestions()

        # Services
        self.session: TranscriptionSession | None = None
        self.extraction_service = ExtractionService(self.settings.openai_api_key)
        self.suggestions_service = SuggestionsService(self.settings.openai_api_key)
        self.soap_service = SOAPService(self.settings.openai_api_key)

        # Task management
        self._extraction_task: asyncio.Task | None = None
        self._suggestions_task: asyncio.Task | None = None
        self._pending_extraction = False
        self._pending_suggestions = False

    async def send_message(self, msg_type: str, **data):
        """Send JSON message to WebSocket client"""
        try:
            await self.websocket.send_json({"type": msg_type, **data})
        except Exception as e:
            print(f"Error sending message: {e}")

    async def on_partial_transcript(self, data: DiarizedTranscript | str):
        """Handle partial transcript (with or without diarization)"""
        if isinstance(data, DiarizedTranscript):
            # Diarized partial
            speaker_role = SpeakerRoleInference.infer_role(
                data.text, data.speaker, self.speaker_history
            )
            await self.send_message(
                "partial",
                text=data.text,
                speaker=data.speaker,
                speaker_role=speaker_role.value,
                start_time=data.start_time,
                end_time=data.end_time
            )
        else:
            # Non-diarized partial
            await self.send_message("partial", text=data)

    async def on_final_transcript(self, data: DiarizedTranscript | str):
        """Handle final transcript and trigger extraction"""
        if isinstance(data, DiarizedTranscript):
            # Diarized final
            speaker_role = SpeakerRoleInference.infer_role(
                data.text, data.speaker, self.speaker_history
            )
            # Update speaker history
            self.speaker_history[data.speaker] = speaker_role

            # Create diarized utterance
            utterance = DiarizedUtterance(
                speaker_id=data.speaker,
                speaker_role=speaker_role,
                text=data.text,
                start_time=data.start_time,
                end_time=data.end_time,
                is_partial=False
            )
            self.diarized_utterances.append(utterance)
            self.transcript_buffer.append(data.text)

            await self.send_message(
                "final",
                text=data.text,
                speaker=data.speaker,
                speaker_role=speaker_role.value,
                start_time=data.start_time,
                end_time=data.end_time
            )
        else:
            # Non-diarized final
            self.transcript_buffer.append(data)
            await self.send_message("final", text=data)

        # Schedule extraction (debounced)
        self._pending_extraction = True
        self._pending_suggestions = True
        if self._extraction_task is None or self._extraction_task.done():
            self._extraction_task = asyncio.create_task(self._debounced_extraction())

    async def _debounced_extraction(self):
        """Debounced extraction to avoid too many API calls"""
        await asyncio.sleep(1.5)  # Wait for more text to accumulate

        if not self._pending_extraction:
            return

        self._pending_extraction = False
        full_transcript = " ".join(self.transcript_buffer)

        try:
            # Extract form data
            self.current_form_data = await self.extraction_service.extract(
                full_transcript,
                self.language
            )
            await self.send_message(
                "form_update",
                data=self.current_form_data.model_dump()
            )

            # Generate suggestions (debounced separately)
            if self._pending_suggestions:
                self._pending_suggestions = False
                if self._suggestions_task is None or self._suggestions_task.done():
                    self._suggestions_task = asyncio.create_task(
                        self._generate_suggestions(full_transcript)
                    )

        except Exception as e:
            print(f"Extraction error: {e}")
            await self.send_message("error", message=f"Extraction error: {e}")

    async def _generate_suggestions(self, transcript: str):
        """Generate AI suggestions"""
        try:
            self.current_suggestions = await self.suggestions_service.generate_suggestions(
                transcript,
                self.current_form_data
            )
            await self.send_message(
                "suggestions_update",
                data=self.current_suggestions.model_dump()
            )
        except Exception as e:
            print(f"Suggestions error: {e}")

    async def generate_soap_note(self):
        """Generate SOAP note and ICD-10 codes from current transcript"""
        if not self.transcript_buffer:
            await self.send_message("error", message="No transcript available for SOAP generation")
            return

        full_transcript = " ".join(self.transcript_buffer)

        try:
            # Generate SOAP note
            soap_note = await self.soap_service.generate_soap(full_transcript, self.current_form_data)
            await self.send_message(
                "soap_update",
                data=soap_note.model_dump()
            )

            # Generate ICD-10 codes
            icd_codes = await self.soap_service.generate_icd_codes(full_transcript, soap_note)
            await self.send_message(
                "icd_codes_update",
                data=[code.model_dump() for code in icd_codes]
            )

        except Exception as e:
            print(f"SOAP generation error: {e}")
            await self.send_message("error", message=f"SOAP generation error: {e}")

    async def on_error(self, error: str):
        """Handle transcription error"""
        await self.send_message("error", message=error)

    async def on_end_of_utterance(self, end_time: float):
        """Handle end of utterance (speaker finished talking)"""
        await self.send_message("end_of_utterance", end_time=end_time)

    async def start(self):
        """Start transcription session"""
        service = TranscriptionService(
            api_key=self.settings.speechmatics_api_key,
            language=self.language,
            speaker_sensitivity=self.speaker_sensitivity,
            prefer_current_speaker=self.prefer_current_speaker,
        )

        self.session = TranscriptionSession(
            service=service,
            on_partial=self.on_partial_transcript,
            on_final=self.on_final_transcript,
            on_error=self.on_error,
            on_end_of_utterance=self.on_end_of_utterance,
            enable_diarization=True,  # Enable speaker diarization
        )

        # Update session state
        self.session_state.is_recording = True
        self.session_state.is_paused = False
        self.session_state.started_at = datetime.now()

        # Start session in background
        asyncio.create_task(self.session.start())

        # Give it time to connect
        await asyncio.sleep(0.5)
        await self.send_message(
            "connected",
            language=self.language,
            session_id=self.session_state.session_id,
            diarization_enabled=True,
            speaker_sensitivity=self.speaker_sensitivity,
            prefer_current_speaker=self.prefer_current_speaker,
        )

    async def send_audio(self, audio_data: bytes):
        """Send audio to transcription session"""
        if self.session:
            await self.session.send_audio(audio_data)

    async def pause(self):
        """Pause transcription session"""
        self.session_state.is_paused = True
        await self.send_message("paused")

    async def resume(self):
        """Resume transcription session"""
        self.session_state.is_paused = False
        await self.send_message("resumed")

    async def stop(self):
        """Stop transcription session"""
        self.session_state.is_recording = False
        self.session_state.is_paused = False

        if self.session:
            await self.session.stop()

        # Final extraction and suggestions
        if self.transcript_buffer:
            full_transcript = " ".join(self.transcript_buffer)
            self.current_form_data = await self.extraction_service.extract(
                full_transcript,
                self.language
            )
            await self.send_message(
                "form_update",
                data=self.current_form_data.model_dump()
            )

            # Final suggestions
            self.current_suggestions = await self.suggestions_service.generate_suggestions(
                full_transcript,
                self.current_form_data
            )
            await self.send_message(
                "suggestions_update",
                data=self.current_suggestions.model_dump()
            )

    def reset(self):
        """Reset transcript buffer and form data"""
        self.transcript_buffer = []
        self.diarized_utterances = []
        self.speaker_history = {}
        self.current_form_data = MedicalFormData()
        self.current_suggestions = AISuggestions()
        self.session_state = SessionState(
            session_id=str(uuid.uuid4()),
            started_at=None,
            is_recording=False,
            is_paused=False
        )

    def set_patient_name(self, name: str):
        """Set patient name for current session"""
        self.session_state.patient_name = name


# Demo endpoint MUST come before /ws/{language} to avoid route conflict
@app.websocket("/ws/demo")
async def demo_websocket(websocket: WebSocket):
    """Demo WebSocket that simulates transcription with diarization and suggestions"""
    print(">>> Demo WebSocket: Connection request received")
    await websocket.accept()
    print(">>> Demo WebSocket: Connection accepted")

    settings = get_settings()
    extraction_service = ExtractionService(settings.openai_api_key)
    suggestions_service = SuggestionsService(settings.openai_api_key)
    soap_service = SOAPService(settings.openai_api_key)

    # Store demo transcript for SOAP generation
    demo_full_transcript = []
    demo_form_data = None

    # Demo transcript segments with speaker roles - bilingual Arabic + English
    # Each segment: (speaker_role, text, start_time, end_time)
    demo_segments = [
        # Doctor intro
        ("doctor", "المريض is a 45 year old male presenting with chest pain.", 0.0, 3.5),
        # Doctor vitals
        ("doctor", "ضغط الدم 140 over 90. نبض القلب 88 beats per minute, regular rhythm.", 4.0, 8.0),
        # Doctor more vitals
        ("doctor", "حرارة 37.2 degrees Celsius. الأكسجين saturation 98 percent.", 8.5, 12.0),
        # Patient symptoms
        ("patient", "I feel shortness of breath و دوخة when I walk.", 12.5, 16.0),
        # Doctor exam
        ("doctor", "الفحص shows mild bilateral leg edema.", 16.5, 19.0),
        # Patient history
        ("patient", "أنا عندي diabetes and السكري hypertension. No known allergies. Currently on metformin.", 19.5, 25.0),
        # Doctor action
        ("doctor", "متابعة recommended in 2 weeks. Discharge is recommended.", 25.5, 29.0),
    ]

    try:
        while True:
            message = await websocket.receive()
            print(f">>> Demo WebSocket: Received message: {message}")

            if "text" in message:
                data = json.loads(message["text"])
                print(f">>> Demo WebSocket: Parsed data type: {data.get('type')}")

                if data.get("type") == "start_demo":
                    import time
                    demo_start = time.time()
                    print(f"Demo: Starting demo mode at {demo_start:.3f}")
                    demo_full_transcript.clear()

                    # Send transcript segments with realistic pacing
                    for i, (speaker_role, segment, start_time, end_time) in enumerate(demo_segments):
                        seg_start = time.time()
                        await websocket.send_json({
                            "type": "final",
                            "text": segment,
                            "speaker": f"S{1 if speaker_role == 'doctor' else 2}",
                            "speaker_role": speaker_role,
                            "start_time": start_time,
                            "end_time": end_time
                        })
                        demo_full_transcript.append(segment)
                        print(f"Demo: Segment {i+1}/7 sent in {(time.time() - seg_start)*1000:.1f}ms")
                        await asyncio.sleep(0.6)  # 600ms between segments for readability

                    print(f"Demo: All segments sent in {(time.time() - demo_start)*1000:.1f}ms total")

                    # Show AI processing indicator
                    await websocket.send_json({"type": "ai_processing", "status": "start"})

                    # Send reasoning steps while processing
                    await websocket.send_json({
                        "type": "reasoning",
                        "text": "Analyzing transcript for medical entities...",
                        "icon": "search"
                    })

                    # Extract and suggest in parallel for speed
                    transcript_text = " ".join(demo_full_transcript)
                    print("Demo: Starting extraction and suggestions in parallel...")
                    ai_start = time.time()

                    await asyncio.sleep(0.3)  # Brief pause for UX
                    await websocket.send_json({
                        "type": "reasoning",
                        "text": "Extracting vitals: BP, heart rate, temperature...",
                        "icon": "vital_signs"
                    })

                    # Run both API calls concurrently
                    extraction_task = extraction_service.extract(transcript_text, "en")
                    suggestions_task = suggestions_service.generate_suggestions(
                        transcript_text, None  # No form data yet, generate based on transcript
                    )

                    # Send more reasoning while waiting
                    await asyncio.sleep(0.5)
                    await websocket.send_json({
                        "type": "reasoning",
                        "text": "Identifying symptoms and clinical findings...",
                        "icon": "symptoms"
                    })

                    await asyncio.sleep(0.5)
                    await websocket.send_json({
                        "type": "reasoning",
                        "text": "Generating differential diagnoses...",
                        "icon": "diagnosis"
                    })

                    demo_form_data, suggestions = await asyncio.gather(
                        extraction_task, suggestions_task
                    )

                    await websocket.send_json({
                        "type": "reasoning",
                        "text": "Preparing clinical recommendations...",
                        "icon": "clinical_notes"
                    })

                    print(f"Demo: AI processing completed in {(time.time() - ai_start)*1000:.1f}ms")

                    # Hide AI processing indicator
                    await websocket.send_json({"type": "ai_processing", "status": "stop"})

                    # Send both updates
                    await websocket.send_json({
                        "type": "form_update",
                        "data": demo_form_data.model_dump()
                    })
                    await websocket.send_json({
                        "type": "suggestions_update",
                        "data": suggestions.model_dump()
                    })

                    print(f"Demo: TOTAL TIME: {(time.time() - demo_start)*1000:.1f}ms")
                    await websocket.send_json({"type": "demo_complete"})

                elif data.get("type") == "generate_soap":
                    print("Demo: Generating SOAP note")
                    if demo_full_transcript:
                        transcript_text = " ".join(demo_full_transcript)

                        # Show AI processing indicator
                        await websocket.send_json({"type": "ai_processing", "status": "start"})

                        await websocket.send_json({
                            "type": "reasoning",
                            "text": "Structuring subjective patient complaints...",
                            "icon": "person"
                        })

                        await asyncio.sleep(0.4)
                        await websocket.send_json({
                            "type": "reasoning",
                            "text": "Compiling objective clinical findings...",
                            "icon": "stethoscope"
                        })

                        # Generate SOAP note
                        soap_note = await soap_service.generate_soap(transcript_text, demo_form_data)

                        await websocket.send_json({
                            "type": "reasoning",
                            "text": "Formulating clinical assessment...",
                            "icon": "psychology"
                        })

                        await asyncio.sleep(0.3)
                        await websocket.send_json({
                            "type": "reasoning",
                            "text": "Mapping to ICD-10 diagnostic codes...",
                            "icon": "code"
                        })

                        # Generate ICD codes
                        icd_codes = await soap_service.generate_icd_codes(transcript_text, soap_note)

                        await websocket.send_json({
                            "type": "reasoning",
                            "text": "Documentation complete.",
                            "icon": "check_circle"
                        })

                        # Hide AI processing indicator
                        await websocket.send_json({"type": "ai_processing", "status": "stop"})

                        await websocket.send_json({
                            "type": "soap_update",
                            "data": soap_note.model_dump()
                        })
                        await websocket.send_json({
                            "type": "icd_codes_update",
                            "data": [code.model_dump() for code in icd_codes]
                        })
                    else:
                        await websocket.send_json({
                            "type": "error",
                            "message": "No transcript available. Run demo first."
                        })

    except WebSocketDisconnect:
        pass


@app.websocket("/ws/{language}")
async def transcription_websocket(websocket: WebSocket, language: str = "ar_en"):
    """WebSocket endpoint for real-time transcription"""
    await websocket.accept()

    # Validate language - ar_en is bilingual Arabic + English
    if language not in ["en", "ar", "ar_en"]:
        await websocket.send_json({
            "type": "error",
            "message": f"Unsupported language: {language}. Use 'en', 'ar', or 'ar_en' (bilingual)."
        })
        await websocket.close()
        return

    manager = TranscriptionManager(websocket, language)

    try:
        while True:
            message = await websocket.receive()

            if "bytes" in message:
                # Audio data
                await manager.send_audio(message["bytes"])

            elif "text" in message:
                # Control message
                try:
                    data = json.loads(message["text"])
                    msg_type = data.get("type")

                    if msg_type == "start":
                        manager.speaker_sensitivity = data.get("speaker_sensitivity", 0.7)
                        manager.prefer_current_speaker = data.get("prefer_current_speaker", True)
                        await manager.start()

                    elif msg_type == "stop":
                        await manager.stop()

                    elif msg_type == "pause":
                        await manager.pause()

                    elif msg_type == "resume":
                        await manager.resume()

                    elif msg_type == "reset":
                        manager.reset()
                        await manager.send_message("reset_complete")

                    elif msg_type == "set_patient":
                        patient_name = data.get("name", "")
                        manager.set_patient_name(patient_name)
                        await manager.send_message("patient_set", name=patient_name)

                    elif msg_type == "ping":
                        await manager.send_message("pong")

                    elif msg_type == "generate_soap":
                        await manager.generate_soap_note()

                except json.JSONDecodeError:
                    await manager.send_message("error", message="Invalid JSON message")

    except WebSocketDisconnect:
        await manager.stop()
    except Exception as e:
        print(f"WebSocket error: {e}")
        await manager.stop()


if __name__ == "__main__":
    import uvicorn
    settings = get_settings()
    uvicorn.run(
        "backend.main:app",
        host=settings.host,
        port=settings.port,
        reload=True
    )
