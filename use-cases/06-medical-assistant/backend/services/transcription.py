"""Speechmatics Voice Agent SDK — medical transcription service"""
import asyncio
from typing import Callable, Awaitable
from dataclasses import dataclass
from speechmatics.voice import (
    VoiceAgentClient,
    VoiceAgentConfig,
    VoiceAgentConfigPreset,
    AgentServerMessageType,
    AdditionalVocabEntry,
    SpeechSegmentConfig,
    OperatingPoint,
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
    """Medical transcription using Speechmatics Voice Agent SDK"""

    # Medical vocabulary for enhanced recognition
    MEDICAL_VOCAB = [
        AdditionalVocabEntry(content="hypertension", sounds_like=["high per tension", "hyper tension"]),
        AdditionalVocabEntry(content="tachycardia", sounds_like=["tacky cardia", "taki cardia"]),
        AdditionalVocabEntry(content="bradycardia", sounds_like=["brady cardia"]),
        AdditionalVocabEntry(content="arrhythmia", sounds_like=["a rithmia", "arrythmia"]),
        AdditionalVocabEntry(content="dyspnea", sounds_like=["disp nea", "dispnea"]),
        AdditionalVocabEntry(content="edema", sounds_like=["e dema"]),
        AdditionalVocabEntry(content="angina", sounds_like=["an gina", "anjina"]),
        AdditionalVocabEntry(content="myocardial", sounds_like=["myo cardial"]),
        AdditionalVocabEntry(content="infarction", sounds_like=["in farction"]),
        AdditionalVocabEntry(content="electrocardiogram", sounds_like=["electro cardio gram", "ECG", "EKG"]),
        AdditionalVocabEntry(content="echocardiogram", sounds_like=["echo cardio gram"]),
        AdditionalVocabEntry(content="auscultation", sounds_like=["aus cul tation"]),
        AdditionalVocabEntry(content="palpitations", sounds_like=["palpi tations"]),
        AdditionalVocabEntry(content="syncope", sounds_like=["sin copy", "sin co pe"]),
        AdditionalVocabEntry(content="cyanosis", sounds_like=["sya nosis", "cyano sis"]),
        AdditionalVocabEntry(content="SpO2", sounds_like=["S P O 2", "spo two", "oxygen saturation"]),
        AdditionalVocabEntry(content="mmHg", sounds_like=["millimeters of mercury", "mm H G"]),
        AdditionalVocabEntry(content="bpm", sounds_like=["beats per minute", "B P M"]),
    ]

    # Arabic medical terms
    ARABIC_MEDICAL_VOCAB = [
        AdditionalVocabEntry(content="ضغط الدم", sounds_like=["daght al dam"]),
        AdditionalVocabEntry(content="نبض القلب", sounds_like=["nabd al qalb"]),
        AdditionalVocabEntry(content="حرارة", sounds_like=["harara"]),
        AdditionalVocabEntry(content="تنفس", sounds_like=["tanaffus"]),
        AdditionalVocabEntry(content="ألم", sounds_like=["alam"]),
        AdditionalVocabEntry(content="صداع", sounds_like=["suda"]),
        AdditionalVocabEntry(content="دوخة", sounds_like=["dawkha"]),
        AdditionalVocabEntry(content="غثيان", sounds_like=["ghathayan"]),
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

    def _get_medical_vocab(self) -> list[AdditionalVocabEntry]:
        """Get appropriate medical vocabulary based on language"""
        if self.language == "en":
            return self.MEDICAL_VOCAB
        elif self.language == "ar":
            return self.ARABIC_MEDICAL_VOCAB
        elif self.language == "ar_en":
            return self.MEDICAL_VOCAB + self.ARABIC_MEDICAL_VOCAB
        return []

    def create_client(self) -> VoiceAgentClient:
        """Create VoiceAgentClient with ADAPTIVE preset + medical overlay.

        ADAPTIVE mode: end-of-utterance is detected automatically using
        adaptive silence timing (0.7s base, adjusts to speech patterns)
        plus VAD.  We override emit_sentences=True so finals stream as
        sentences complete (needed to drive extraction).
        """
        config = VoiceAgentConfigPreset.ADAPTIVE(VoiceAgentConfig(
            language=self.language,
            domain="medical",
            operating_point=OperatingPoint.ENHANCED,
            enable_entities=True,
            enable_diarization=True,
            speaker_sensitivity=self.speaker_sensitivity,
            prefer_current_speaker=self.prefer_current_speaker,
            max_speakers=2,
            additional_vocab=self._get_medical_vocab(),
            speech_segment_config=SpeechSegmentConfig(emit_sentences=True),
            advanced_engine_control={
                "audio_filtering_config": {
                    "volume_threshold": 3.4,
                },
            },
        ))
        return VoiceAgentClient(
            api_key=self.api_key,
            url=self.RT_URL,
            config=config,
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
        self._client: VoiceAgentClient | None = None
        self._running = False

    def _parse_segment(self, segment: dict, metadata: dict, is_partial: bool) -> DiarizedTranscript:
        """Parse a Voice Agent segment into DiarizedTranscript"""
        return DiarizedTranscript(
            text=segment.get("text", ""),
            speaker=segment.get("speaker_id", "UNK"),
            start_time=metadata.get("start_time", 0.0),
            end_time=metadata.get("end_time", 0.0),
            is_partial=is_partial,
        )

    async def start(self):
        """Connect to Speechmatics and start transcription"""
        self._client = self.service.create_client()

        # Event handlers (sync — Voice Agent SDK pattern)
        def on_partial_segment(message):
            if not self._running:
                return
            metadata = message.get("metadata", {})
            for seg in message.get("segments", []):
                if not seg.get("text"):
                    continue
                diarized = self._parse_segment(seg, metadata, is_partial=True)
                asyncio.create_task(self.on_partial(diarized))

        def on_segment(message):
            if not self._running:
                return
            metadata = message.get("metadata", {})
            for seg in message.get("segments", []):
                if not seg.get("text"):
                    continue
                diarized = self._parse_segment(seg, metadata, is_partial=False)
                asyncio.create_task(self.on_final(diarized))

        def on_error(message):
            reason = message.get("reason", "Unknown error")
            print(f"Speechmatics error: {reason}")
            if self.on_error:
                asyncio.create_task(self.on_error(reason))

        def on_recognition_started(message):
            print("Speechmatics: Recognition started (Voice Agent SDK, ADAPTIVE preset)")

        # Register handlers
        self._client.on(AgentServerMessageType.ADD_PARTIAL_SEGMENT, on_partial_segment)
        self._client.on(AgentServerMessageType.ADD_SEGMENT, on_segment)
        self._client.on(AgentServerMessageType.ERROR, on_error)
        self._client.on(AgentServerMessageType.RECOGNITION_STARTED, on_recognition_started)

        # Connect — returns when session is established
        try:
            await self._client.connect()
            self._running = True
        except Exception as e:
            error_msg = str(e)
            print(f"Transcription session error: {error_msg}")
            if self.on_error:
                await self.on_error(error_msg)

    async def send_audio(self, audio_data: bytes):
        """Send audio data to the transcription service"""
        if self._running and self._client:
            try:
                await self._client.send_audio(audio_data)
            except Exception as e:
                print(f"Error sending audio: {e}")

    async def stop(self):
        """Stop the transcription session"""
        self._running = False
        if self._client:
            try:
                await self._client.disconnect()
            except Exception as e:
                print(f"Error stopping session: {e}")
