"""Speechmatics real-time transcription service using speechmatics-rt SDK"""
import asyncio
from typing import Callable, Awaitable
from dataclasses import dataclass
from speechmatics.rt import (
    AsyncClient,
    TranscriptionConfig,
    AudioFormat,
    AudioEncoding,
    ServerMessageType,
    OperatingPoint,
    SpeakerDiarizationConfig,
    ConversationConfig,
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
    """Real-time transcription using Speechmatics RT API"""

    # Medical vocabulary for enhanced recognition
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
        # ar_en = bilingual Arabic + English support
        self.language = language
        self.speaker_sensitivity = speaker_sensitivity
        self.prefer_current_speaker = prefer_current_speaker

    def _get_medical_vocab(self) -> list:
        """Get appropriate medical vocabulary based on language"""
        if self.language == "en":
            return self.MEDICAL_VOCAB
        elif self.language == "ar":
            return self.ARABIC_MEDICAL_VOCAB
        elif self.language == "ar_en":
            # Bilingual: include both vocabularies
            return self.MEDICAL_VOCAB + self.ARABIC_MEDICAL_VOCAB
        return []

    def get_transcription_config(self, enable_diarization: bool = True) -> TranscriptionConfig:
        """Create transcription configuration optimized for medical speech"""
        config = TranscriptionConfig(
            language=self.language,
            operating_point=OperatingPoint.ENHANCED,  # Best accuracy
            enable_partials=True,
            max_delay=2.0,
            enable_entities=True,
            additional_vocab=self._get_medical_vocab(),
            # Enable turn detection - detects when speaker finishes talking
            conversation_config=ConversationConfig(
                end_of_utterance_silence_trigger=0.8,  # 800ms silence triggers end of turn
            ),
        )

        # Enable speaker diarization for doctor/patient identification
        if enable_diarization:
            config.diarization = "speaker"
            config.speaker_diarization_config = SpeakerDiarizationConfig(
                max_speakers=2,  # Doctor + Patient
                speaker_sensitivity=self.speaker_sensitivity,
                prefer_current_speaker=self.prefer_current_speaker,
            )

        # Enable medical domain for improved clinical vocabulary recognition
        config.domain = "medical"

        return config

    def get_audio_format(self) -> AudioFormat:
        """Get audio format for browser input"""
        return AudioFormat(
            encoding=AudioEncoding.PCM_S16LE,
            sample_rate=16000,
        )

    def create_client(self) -> AsyncClient:
        """Create a new AsyncClient instance"""
        return AsyncClient(
            api_key=self.api_key,
            url=self.RT_URL,
        )


class TranscriptionSession:
    """Manages a single transcription session"""

    def __init__(
        self,
        service: TranscriptionService,
        on_partial: Callable[[str], Awaitable[None]] | Callable[[DiarizedTranscript], Awaitable[None]],
        on_final: Callable[[str], Awaitable[None]] | Callable[[DiarizedTranscript], Awaitable[None]],
        on_error: Callable[[str], Awaitable[None]] | None = None,
        on_end_of_utterance: Callable[[float], Awaitable[None]] | None = None,
        enable_diarization: bool = True,
    ):
        self.service = service
        self.on_partial = on_partial
        self.on_final = on_final
        self.on_error = on_error
        self.on_end_of_utterance = on_end_of_utterance
        self.enable_diarization = enable_diarization
        self._client: AsyncClient | None = None
        self._running = False
        self._connected = False

    async def start(self):
        """Start the transcription session"""
        self._running = True

        transcription_config = self.service.get_transcription_config(
            enable_diarization=self.enable_diarization
        )
        audio_format = self.service.get_audio_format()

        # Create the client
        self._client = self.service.create_client()

        # Set up event handlers
        @self._client.on(ServerMessageType.RECOGNITION_STARTED)
        def on_started(msg):
            print("Speechmatics: Recognition started")
            diarization_status = "enabled" if self.enable_diarization else "disabled"
            print(f"Speechmatics: Diarization {diarization_status}")
            self._connected = True

        @self._client.on(ServerMessageType.ADD_PARTIAL_TRANSCRIPT)
        def on_partial(msg):
            if not self._running:
                return

            # Extract transcript from partial
            transcript = msg.get("metadata", {}).get("transcript", "")
            if not transcript:
                return

            if self.enable_diarization:
                # For partials, we get speaker from the results array
                results = msg.get("results", [])
                speaker = "UNK"
                start_time = 0.0
                end_time = 0.0

                if results:
                    # Get speaker from first result's alternatives
                    first_result = results[0]
                    start_time = first_result.get("start_time", 0.0)
                    end_time = first_result.get("end_time", 0.0)
                    alternatives = first_result.get("alternatives", [])
                    if alternatives:
                        speaker = alternatives[0].get("speaker", "UNK")

                diarized = DiarizedTranscript(
                    text=transcript,
                    speaker=speaker,
                    start_time=start_time,
                    end_time=end_time,
                    is_partial=True
                )
                asyncio.create_task(self.on_partial(diarized))
            else:
                asyncio.create_task(self.on_partial(transcript))

        @self._client.on(ServerMessageType.ADD_TRANSCRIPT)
        def on_final(msg):
            if not self._running:
                return

            # Extract transcript from final
            transcript = msg.get("metadata", {}).get("transcript", "")
            if not transcript:
                return

            if self.enable_diarization:
                # For finals, extract speaker info from results
                results = msg.get("results", [])
                speaker = "UNK"
                start_time = 0.0
                end_time = 0.0

                if results:
                    first_result = results[0]
                    start_time = first_result.get("start_time", 0.0)

                    # Get end_time from last result
                    last_result = results[-1]
                    end_time = last_result.get("end_time", 0.0)

                    # Get speaker from first result's alternatives
                    alternatives = first_result.get("alternatives", [])
                    if alternatives:
                        speaker = alternatives[0].get("speaker", "UNK")

                diarized = DiarizedTranscript(
                    text=transcript,
                    speaker=speaker,
                    start_time=start_time,
                    end_time=end_time,
                    is_partial=False
                )
                asyncio.create_task(self.on_final(diarized))
            else:
                asyncio.create_task(self.on_final(transcript))

        @self._client.on(ServerMessageType.ERROR)
        def on_error(msg):
            reason = msg.get("reason", "Unknown error")
            print(f"Speechmatics error: {reason}")
            if self.on_error:
                asyncio.create_task(self.on_error(reason))

        @self._client.on(ServerMessageType.END_OF_UTTERANCE)
        def on_utterance_end(msg):
            """Handle end of utterance (turn detection)"""
            end_time = msg.get("end_of_utterance_time", 0.0)
            print(f"Speechmatics: End of utterance at {end_time:.2f}s")
            if self.on_end_of_utterance:
                asyncio.create_task(self.on_end_of_utterance(end_time))

        @self._client.on(ServerMessageType.END_OF_TRANSCRIPT)
        def on_end(msg):
            print("Speechmatics: End of transcript")
            self._running = False

        # Start the session
        try:
            async with self._client:
                await self._client.start_session(
                    transcription_config=transcription_config,
                    audio_format=audio_format,
                )

                # Keep session alive while running
                while self._running:
                    await asyncio.sleep(0.1)

        except Exception as e:
            error_msg = str(e)
            print(f"Transcription session error: {error_msg}")
            if self.on_error:
                await self.on_error(error_msg)

    async def send_audio(self, audio_data: bytes):
        """Send audio data to the transcription service"""
        if self._running and self._client and self._connected:
            try:
                await self._client.send_audio(audio_data)
            except Exception as e:
                print(f"Error sending audio: {e}")

    async def stop(self):
        """Stop the transcription session"""
        self._running = False
        if self._client:
            try:
                await self._client.stop_session()
            except Exception as e:
                print(f"Error stopping session: {e}")
