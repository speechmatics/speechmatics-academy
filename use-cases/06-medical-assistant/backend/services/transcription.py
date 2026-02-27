"""Speechmatics RT SDK — medical transcription service"""
import asyncio
from collections import Counter
from typing import Callable, Awaitable
from dataclasses import dataclass
from speechmatics.rt import (
    AsyncClient,
    AudioEncoding,
    AudioFormat,
    ConversationConfig,
    OperatingPoint,
    ServerMessageType,
    SpeakerDiarizationConfig,
    TranscriptionConfig,
)


@dataclass
class DiarizedTranscript:
    """Transcript with speaker information"""
    text: str
    speaker: str  # "S1", "S2", etc. from Speechmatics
    start_time: float
    end_time: float
    is_partial: bool = False


class TranscriptionService:
    """Medical transcription using Speechmatics RT SDK"""

    # Medical vocabulary for enhanced recognition (plain dicts for RT SDK)
    MEDICAL_VOCAB = [
        {"content": "hypertension", "sounds_like": ["high per tension", "hyper tension"]},
        {"content": "tachycardia", "sounds_like": ["tacky cardia", "taki cardia"]},
        {"content": "bradycardia", "sounds_like": ["brady cardia"]},
        {"content": "arrhythmia", "sounds_like": ["a rithmia", "arrythmia"]},
        {"content": "dyspnea", "sounds_like": ["disp nea", "dispnea"]},
        {"content": "edema", "sounds_like": ["e dema"]},
        {"content": "angina", "sounds_like": ["an gina", "anjina"]},
        {"content": "myocardial", "sounds_like": ["myo cardial"]},
        {"content": "infarction", "sounds_like": ["in farction"]},
        {"content": "electrocardiogram", "sounds_like": ["electro cardio gram", "ECG", "EKG"]},
        {"content": "echocardiogram", "sounds_like": ["echo cardio gram"]},
        {"content": "auscultation", "sounds_like": ["aus cul tation"]},
        {"content": "palpitations", "sounds_like": ["palpi tations"]},
        {"content": "syncope", "sounds_like": ["sin copy", "sin co pe"]},
        {"content": "cyanosis", "sounds_like": ["sya nosis", "cyano sis"]},
        {"content": "SpO2", "sounds_like": ["S P O 2", "spo two", "oxygen saturation"]},
        {"content": "mmHg", "sounds_like": ["millimeters of mercury", "mm H G"]},
        {"content": "bpm", "sounds_like": ["beats per minute", "B P M"]},
    ]

    # Arabic medical terms
    ARABIC_MEDICAL_VOCAB = [
        {"content": "ضغط الدم", "sounds_like": ["daght al dam"]},
        {"content": "نبض القلب", "sounds_like": ["nabd al qalb"]},
        {"content": "حرارة", "sounds_like": ["harara"]},
        {"content": "تنفس", "sounds_like": ["tanaffus"]},
        {"content": "ألم", "sounds_like": ["alam"]},
        {"content": "صداع", "sounds_like": ["suda"]},
        {"content": "دوخة", "sounds_like": ["dawkha"]},
        {"content": "غثيان", "sounds_like": ["ghathayan"]},
    ]

    # Preview RT API endpoint (supports bilingual ar_en)
    RT_URL = "wss://preview.rt.speechmatics.com/v2"

    def __init__(self, api_key: str, language: str = "ar_en",
                 speaker_sensitivity: float = 0.7,
                 prefer_current_speaker: bool = True):
        self.api_key = api_key
        self.language = language
        self.speaker_sensitivity = speaker_sensitivity
        self.prefer_current_speaker = prefer_current_speaker

    @property
    def diarization_settings(self) -> dict:
        """Current diarization settings for client transparency"""
        return {
            "diarization_enabled": True,
            "speaker_sensitivity": self.speaker_sensitivity,
            "prefer_current_speaker": self.prefer_current_speaker,
        }

    def _get_medical_vocab(self) -> list[dict]:
        """Get appropriate medical vocabulary based on language"""
        if self.language == "en":
            return self.MEDICAL_VOCAB
        elif self.language == "ar":
            return self.ARABIC_MEDICAL_VOCAB
        elif self.language == "ar_en":
            return self.MEDICAL_VOCAB + self.ARABIC_MEDICAL_VOCAB
        return []

    def _build_transcription_config(self) -> TranscriptionConfig:
        """Build RT SDK transcription config with medical settings."""
        return TranscriptionConfig(
            language=self.language,
            operating_point=OperatingPoint.ENHANCED,
            domain="medical",
            enable_entities=True,
            enable_partials=True,
            diarization="speaker",
            speaker_diarization_config=SpeakerDiarizationConfig(
                max_speakers=2,
                speaker_sensitivity=self.speaker_sensitivity,
                prefer_current_speaker=self.prefer_current_speaker,
            ),
            additional_vocab=self._get_medical_vocab(),
            audio_filtering_config={"volume_threshold": 3.4},
            conversation_config=ConversationConfig(
                end_of_utterance_silence_trigger=0.7,
            ),
            max_delay=2.0,
        )

    def _build_audio_format(self) -> AudioFormat:
        """Build audio format for raw PCM from browser microphone."""
        return AudioFormat(
            encoding=AudioEncoding.PCM_S16LE,
            sample_rate=16000,
            chunk_size=4096,
        )


class TranscriptionSession:
    """Manages a single transcription session"""

    def __init__(
        self,
        service: TranscriptionService,
        on_partial: Callable[[DiarizedTranscript], Awaitable[None]],
        on_final: Callable[[DiarizedTranscript], Awaitable[None]],
        on_error: Callable[[str], Awaitable[None]] | None = None,
    ):
        self.service = service
        self.on_partial = on_partial
        self.on_final = on_final
        self.on_error = on_error
        self._client: AsyncClient | None = None
        self._running = False
        # Accumulate finals until END_OF_UTTERANCE (RT SDK fires ADD_TRANSCRIPT
        # per word/phrase, not per sentence — we batch them into full utterances)
        self._utterance_texts: list[str] = []
        self._utterance_speakers: list[str] = []
        self._utterance_start: float = 0.0
        self._utterance_end: float = 0.0

    def _get_dominant_speaker(self, results: list[dict]) -> str:
        """Extract dominant speaker from per-word results."""
        speakers = []
        for result in results:
            if result.get("type") != "word":
                continue
            alts = result.get("alternatives", [])
            if alts and "speaker" in alts[0]:
                speakers.append(alts[0]["speaker"])
        if not speakers:
            return "UNK"
        counts = Counter(speakers)
        return counts.most_common(1)[0][0]

    def _parse_transcript(self, message: dict, is_partial: bool) -> DiarizedTranscript:
        """Parse an RT SDK transcript message into DiarizedTranscript"""
        metadata = message.get("metadata", {})
        return DiarizedTranscript(
            text=metadata.get("transcript", ""),
            speaker=self._get_dominant_speaker(message.get("results", [])),
            start_time=metadata.get("start_time", 0.0),
            end_time=metadata.get("end_time", 0.0),
            is_partial=is_partial,
        )

    async def start(self):
        """Connect to Speechmatics and start transcription"""
        self._client = AsyncClient(
            api_key=self.service.api_key,
            url=self.service.RT_URL,
        )

        # Enter the async context manager manually (start() must return)
        await self._client.__aenter__()

        # Event handlers (sync — RT SDK requirement)
        @self._client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
        def on_partial(message):
            if not self._running:
                return
            text = message.get("metadata", {}).get("transcript", "")
            if not text.strip():
                return
            diarized = self._parse_transcript(message, is_partial=True)
            asyncio.create_task(self.on_partial(diarized))

        @self._client.on(ServerMessageType.ADD_TRANSCRIPT)
        def on_final(message):
            """Accumulate final segments — emit on END_OF_UTTERANCE."""
            if not self._running:
                return
            metadata = message.get("metadata", {})
            text = metadata.get("transcript", "")
            if not text.strip():
                return
            # Track start time from first segment in utterance
            if not self._utterance_texts:
                self._utterance_start = metadata.get("start_time", 0.0)
            self._utterance_end = metadata.get("end_time", 0.0)
            self._utterance_texts.append(text.strip())
            # Collect per-word speakers for dominant speaker calculation
            speaker = self._get_dominant_speaker(message.get("results", []))
            if speaker != "UNK":
                self._utterance_speakers.append(speaker)

        @self._client.on(ServerMessageType.END_OF_UTTERANCE)
        def on_eou(message):
            """Flush accumulated finals as one complete utterance."""
            if not self._running or not self._utterance_texts:
                return
            # Build combined utterance
            full_text = " ".join(self._utterance_texts)
            # Dominant speaker across all segments
            if self._utterance_speakers:
                counts = Counter(self._utterance_speakers)
                speaker = counts.most_common(1)[0][0]
            else:
                speaker = "UNK"
            diarized = DiarizedTranscript(
                text=full_text,
                speaker=speaker,
                start_time=self._utterance_start,
                end_time=self._utterance_end,
                is_partial=False,
            )
            # Clear accumulator
            self._utterance_texts.clear()
            self._utterance_speakers.clear()
            self._utterance_start = 0.0
            self._utterance_end = 0.0
            asyncio.create_task(self.on_final(diarized))

        @self._client.on(ServerMessageType.ERROR)
        def on_error(message):
            reason = message.get("reason", "Unknown error")
            print(f"Speechmatics error: {reason}")
            if self.on_error:
                asyncio.create_task(self.on_error(reason))

        @self._client.on(ServerMessageType.RECOGNITION_STARTED)
        def on_recognition_started(message):
            session_id = message.get("id", "unknown")
            print(f"Speechmatics: Recognition started (RT SDK, session {session_id})")

        # Connect and start session
        try:
            await self._client.start_session(
                transcription_config=self.service._build_transcription_config(),
                audio_format=self.service._build_audio_format(),
            )
            self._running = True
        except Exception as e:
            error_msg = str(e)
            print(f"Transcription session error: {error_msg}")
            if self.on_error:
                await self.on_error(error_msg)
            # Clean up the context manager on failure
            await self._client.__aexit__(None, None, None)
            self._client = None

    async def send_audio(self, audio_data: bytes):
        """Send audio data to the transcription service"""
        if self._running and self._client:
            try:
                await self._client.send_audio(audio_data)
            except Exception as e:
                print(f"Error sending audio: {e}")

    def _flush_utterance(self):
        """Flush any accumulated finals as a final utterance."""
        if not self._utterance_texts:
            return
        full_text = " ".join(self._utterance_texts)
        if self._utterance_speakers:
            counts = Counter(self._utterance_speakers)
            speaker = counts.most_common(1)[0][0]
        else:
            speaker = "UNK"
        diarized = DiarizedTranscript(
            text=full_text,
            speaker=speaker,
            start_time=self._utterance_start,
            end_time=self._utterance_end,
            is_partial=False,
        )
        self._utterance_texts.clear()
        self._utterance_speakers.clear()
        asyncio.create_task(self.on_final(diarized))

    async def stop(self):
        """Stop the transcription session"""
        # Flush any remaining accumulated text before stopping
        self._flush_utterance()
        self._running = False
        if self._client:
            try:
                await self._client.stop_session()
            except Exception as e:
                print(f"Error stopping session: {e}")
            try:
                await self._client.__aexit__(None, None, None)
            except Exception as e:
                print(f"Error closing client: {e}")
            self._client = None
