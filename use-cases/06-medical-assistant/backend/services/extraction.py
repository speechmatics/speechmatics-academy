"""GPT-4 medical form extraction and AI suggestions service"""
from typing import Optional
from enum import Enum
from pydantic import BaseModel, Field
from openai import AsyncOpenAI


class SpeakerRole(str, Enum):
    """Speaker role in conversation"""
    DOCTOR = "doctor"
    PATIENT = "patient"
    UNKNOWN = "unknown"


class DiarizedUtterance(BaseModel):
    """A single utterance with speaker identification"""
    speaker_id: str  # "S1", "S2" from Speechmatics
    speaker_role: SpeakerRole
    text: str
    start_time: float
    end_time: float
    is_partial: bool = False


class ClinicalSuggestion(BaseModel):
    """AI-generated clinical suggestion"""
    id: str
    text: str
    priority: str = "normal"  # "low", "normal", "high", "critical"
    rationale: Optional[str] = None


class SOAPNote(BaseModel):
    """SOAP note structure"""
    subjective: str = Field(default="", description="Patient's symptoms, history, and complaints")
    objective: str = Field(default="", description="Physical exam findings, vitals, observations")
    assessment: str = Field(default="", description="Clinical assessment and diagnosis")
    plan: str = Field(default="", description="Treatment plan and follow-up")


class ICDCode(BaseModel):
    """ICD-10 code suggestion"""
    code: str
    description: str
    confidence: float = Field(default=0.8, ge=0, le=1.0)


class AISuggestions(BaseModel):
    """All AI-generated suggestions"""
    questions_to_ask: list[ClinicalSuggestion] = Field(default_factory=list)
    potential_diagnoses: list[ClinicalSuggestion] = Field(default_factory=list)
    tests_to_consider: list[ClinicalSuggestion] = Field(default_factory=list)
    medications_to_consider: list[ClinicalSuggestion] = Field(default_factory=list)
    referrals: list[ClinicalSuggestion] = Field(default_factory=list)


class VitalsData(BaseModel):
    """Patient vital signs"""
    blood_pressure: Optional[str] = Field(None, description="Blood pressure reading (e.g., '120/80')")
    pulse: Optional[int] = Field(None, description="Pulse rate in bpm")
    temperature: Optional[float] = Field(None, description="Body temperature")
    respiratory_rate: Optional[int] = Field(None, description="Respiratory rate per minute")
    spo2: Optional[int] = Field(None, description="Oxygen saturation percentage")
    rhythm: Optional[str] = Field(None, description="Heart rhythm (e.g., 'regular', 'irregular')")


class MedicalFormData(BaseModel):
    """Extracted medical form data"""
    physical_examination: Optional[str] = Field(None, description="Physical examination findings")
    other_details: Optional[str] = Field(None, description="Additional clinical details")
    symptoms: Optional[list[str]] = Field(None, description="List of reported symptoms")
    action: Optional[str] = Field(None, description="Recommended action (Follow-up, Referral, Admit, Discharge, Observation)")
    review_after: Optional[str] = Field(None, description="Follow-up timing (1 week, 2 weeks, 1 month, 3 months, 6 months)")
    discharge_recommended: Optional[bool] = Field(None, description="Whether discharge is recommended")
    vitals: Optional[VitalsData] = Field(None, description="Vital signs")



class SpeakerRoleInference:
    """Infer speaker role (doctor/patient) from utterance patterns"""

    # Doctor patterns (English and Arabic)
    DOCTOR_PATTERNS = [
        # English clinical language
        "blood pressure", "pulse", "temperature", "let me examine",
        "i recommend", "i suggest", "prescribed", "diagnosis",
        "your vitals", "your symptoms", "examination shows",
        "we need to", "i'll order", "the test", "follow-up",
        # Arabic clinical language
        "ضغط الدم", "نبض", "حرارة", "الفحص", "الفحص يظهر",
        "أنصح", "أوصي", "العلاج", "التشخيص", "المتابعة",
    ]

    # Patient patterns (English and Arabic)
    PATIENT_PATTERNS = [
        # English patient language
        "i feel", "i have", "it hurts", "i'm experiencing",
        "my pain", "when i", "i can't", "i've been",
        "started yesterday", "woke up with", "since last",
        # Arabic patient language
        "أشعر", "عندي", "يؤلمني", "ألم في", "منذ",
        "بدأت", "أعاني من", "لا أستطيع",
    ]

    @classmethod
    def infer_role(cls, text: str, speaker_id: str, speaker_history: dict[str, SpeakerRole]) -> SpeakerRole:
        """Infer speaker role from text patterns and history"""
        text_lower = text.lower()

        # Check patterns
        doctor_score = sum(1 for p in cls.DOCTOR_PATTERNS if p in text_lower)
        patient_score = sum(1 for p in cls.PATIENT_PATTERNS if p in text_lower)

        # If clear winner from patterns
        if doctor_score > patient_score:
            return SpeakerRole.DOCTOR
        elif patient_score > doctor_score:
            return SpeakerRole.PATIENT

        # Check history for this speaker
        if speaker_id in speaker_history:
            return speaker_history[speaker_id]

        # Default: first speaker (S1) is typically doctor
        if speaker_id == "S1":
            return SpeakerRole.DOCTOR
        elif speaker_id == "S2":
            return SpeakerRole.PATIENT

        return SpeakerRole.UNKNOWN


class ExtractionService:
    """Extract structured medical data from transcripts using GPT-4"""

    SYSTEM_PROMPT = """You are a medical transcription assistant. Extract structured medical form data from clinical conversations.

Return a JSON object with EXACTLY these field names (use snake_case):

{
  "physical_examination": "string or null - physical exam findings",
  "other_details": "string or null - additional clinical notes",
  "symptoms": ["array of strings"] or null,
  "action": "Follow-up|Referral|Admit|Discharge|Observation" or null,
  "review_after": "1 week|2 weeks|1 month|3 months|6 months" or null,
  "discharge_recommended": true/false or null,
  "vitals": {
    "blood_pressure": "string like 120/80" or null,
    "pulse": integer or null,
    "temperature": float or null,
    "respiratory_rate": integer or null,
    "spo2": integer or null,
    "rhythm": "string" or null
  } or null
}

Rules:
- Use EXACTLY the field names shown above (snake_case)
- Only extract EXPLICITLY mentioned information
- Return null for unmentioned fields
- For Arabic, translate terms to English"""

    def __init__(self, api_key: str):
        self.client = AsyncOpenAI(api_key=api_key)

    async def extract(self, transcript: str, language: str = "en") -> MedicalFormData:
        """Extract medical form data from transcript"""
        print(f"Extraction: Called with transcript length {len(transcript)}")
        if not transcript.strip():
            print("Extraction: Empty transcript, returning empty form")
            return MedicalFormData()

        user_prompt = f"""Extract medical form data from this {'Arabic' if language == 'ar' else 'English'} clinical transcript:

---
{transcript}
---

Return a JSON object with the extracted information."""

        try:
            print(f"Extraction: Calling GPT-4 with {len(transcript)} chars...")
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.1,  # Low temperature for consistent extraction
                max_tokens=1000,
            )

            content = response.choices[0].message.content
            print(f"Extraction: GPT-4 returned: {content[:200]}...")
            form_data = MedicalFormData.model_validate_json(content)
            print(f"Extraction: Parsed successfully - vitals={form_data.vitals}, symptoms={form_data.symptoms}")

            # Normalize blood pressure format (convert "over" to "/")
            if form_data.vitals and form_data.vitals.blood_pressure:
                form_data.vitals.blood_pressure = self._normalize_bp(form_data.vitals.blood_pressure)

            return form_data

        except Exception as e:
            # Log error but return empty form data
            import traceback
            print(f"Extraction error: {e}")
            traceback.print_exc()
            return MedicalFormData()

    def _normalize_bp(self, bp_value: str) -> str:
        """Normalize blood pressure format (e.g., '145 over 95' -> '145/95')"""
        import re
        # Replace various "over" formats with "/"
        normalized = re.sub(r'\s*over\s*', '/', bp_value, flags=re.IGNORECASE)
        normalized = re.sub(r'\s*על\s*', '/', normalized)  # Hebrew "over"
        normalized = re.sub(r'\s*على\s*', '/', normalized)  # Arabic "over"
        # Clean up any extra spaces around the slash
        normalized = re.sub(r'\s*/\s*', '/', normalized)
        return normalized.strip()



class SuggestionsService:
    """Generate AI clinical suggestions from transcripts"""

    SUGGESTIONS_PROMPT = """You are a clinical decision support assistant. Based on the medical conversation transcript, generate helpful suggestions for the healthcare provider.

Analyze the transcript and return a JSON object with these fields:

{
  "questions_to_ask": [
    {"id": "q1", "text": "question to ask patient", "priority": "normal|high", "rationale": "why ask this"}
  ],
  "potential_diagnoses": [
    {"id": "d1", "text": "possible diagnosis", "priority": "normal|high", "rationale": "clinical reasoning"}
  ],
  "tests_to_consider": [
    {"id": "t1", "text": "test name", "priority": "normal|high", "rationale": "why this test"}
  ],
  "medications_to_consider": [
    {"id": "m1", "text": "medication suggestion", "priority": "normal", "rationale": "indication"}
  ],
  "referrals": [
    {"id": "r1", "text": "specialty referral", "priority": "normal", "rationale": "reason for referral"}
  ]
}

Guidelines:
- Generate 0-4 items per category based on clinical relevance
- Prioritize clinically actionable suggestions
- Base all suggestions on explicitly mentioned symptoms and findings
- If the transcript is minimal or unclear, return empty arrays
- For Arabic transcripts, provide suggestions in English"""

    def __init__(self, api_key: str):
        self.client = AsyncOpenAI(api_key=api_key)
        self._suggestion_counter = 0

    def _generate_id(self, prefix: str) -> str:
        """Generate unique ID for suggestions"""
        self._suggestion_counter += 1
        return f"{prefix}_{self._suggestion_counter}"

    async def generate_suggestions(self, transcript: str, form_data: Optional[MedicalFormData] = None) -> AISuggestions:
        """Generate AI suggestions from transcript"""
        if not transcript or len(transcript.strip()) < 20:
            return AISuggestions()

        # Build context from form data if available
        context_parts = [f"Transcript: {transcript}"]
        if form_data:
            if form_data.symptoms:
                context_parts.append(f"Symptoms: {', '.join(form_data.symptoms)}")
            if form_data.vitals:
                vitals_str = []
                if form_data.vitals.blood_pressure:
                    vitals_str.append(f"BP: {form_data.vitals.blood_pressure}")
                if form_data.vitals.pulse:
                    vitals_str.append(f"Pulse: {form_data.vitals.pulse}")
                if form_data.vitals.spo2:
                    vitals_str.append(f"SpO2: {form_data.vitals.spo2}")
                if vitals_str:
                    context_parts.append(f"Vitals: {', '.join(vitals_str)}")

        user_prompt = f"""Analyze this clinical encounter and generate suggestions:

---
{chr(10).join(context_parts)}
---

Return a JSON object with clinical suggestions."""

        try:
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": self.SUGGESTIONS_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.3,  # Slightly higher for creative suggestions
                max_tokens=1500,
            )

            content = response.choices[0].message.content
            suggestions = AISuggestions.model_validate_json(content)

            # Ensure all items have valid IDs
            for q in suggestions.questions_to_ask:
                if not q.id:
                    q.id = self._generate_id("q")
            for d in suggestions.potential_diagnoses:
                if not d.id:
                    d.id = self._generate_id("d")
            for t in suggestions.tests_to_consider:
                if not t.id:
                    t.id = self._generate_id("t")
            for m in suggestions.medications_to_consider:
                if not m.id:
                    m.id = self._generate_id("m")
            for r in suggestions.referrals:
                if not r.id:
                    r.id = self._generate_id("r")

            return suggestions

        except Exception as e:
            import traceback
            print(f"Suggestions error: {e}")
            traceback.print_exc()
            return AISuggestions()


class SOAPService:
    """Generate SOAP notes and ICD-10 codes from transcripts"""

    SOAP_PROMPT = """You are a medical documentation assistant. Generate a SOAP note from the clinical conversation.

Return a JSON object with EXACTLY these fields:
{
  "subjective": "Patient's reported symptoms, medical history, and chief complaint. Quote patient's own words when possible.",
  "objective": "Physical examination findings, vital signs, and observable clinical data.",
  "assessment": "Clinical assessment including working diagnosis and differential diagnoses.",
  "plan": "Treatment plan, medications, tests ordered, follow-up instructions, and patient education."
}

Guidelines:
- Use professional medical terminology
- Be concise but comprehensive
- Only include information explicitly mentioned in the transcript
- If a section has no relevant information, use "Not documented" or similar
- Translate any Arabic terms to English"""

    ICD_PROMPT = """You are a medical coding assistant. Based on the clinical transcript and SOAP note, suggest appropriate ICD-10 diagnosis codes.

Return a JSON object:
{
  "codes": [
    {"code": "I10", "description": "Essential (primary) hypertension", "confidence": 0.9},
    {"code": "E11.9", "description": "Type 2 diabetes mellitus without complications", "confidence": 0.85}
  ]
}

Guidelines:
- Only suggest codes for conditions explicitly mentioned or clearly implied
- Include confidence score (0.5-1.0) based on how clearly the condition is documented
- Order by relevance (primary diagnosis first)
- Limit to 3-5 most relevant codes
- Use current ICD-10-CM codes"""

    def __init__(self, api_key: str):
        self.client = AsyncOpenAI(api_key=api_key)

    async def generate_soap(self, transcript: str, form_data: Optional[MedicalFormData] = None) -> SOAPNote:
        """Generate SOAP note from transcript"""
        if not transcript or len(transcript.strip()) < 20:
            return SOAPNote()

        # Build context
        context_parts = [f"Clinical Transcript:\n{transcript}"]
        if form_data:
            if form_data.vitals:
                vitals_info = []
                if form_data.vitals.blood_pressure:
                    vitals_info.append(f"BP: {form_data.vitals.blood_pressure}")
                if form_data.vitals.pulse:
                    vitals_info.append(f"Pulse: {form_data.vitals.pulse}")
                if form_data.vitals.temperature:
                    vitals_info.append(f"Temp: {form_data.vitals.temperature}")
                if form_data.vitals.spo2:
                    vitals_info.append(f"SpO2: {form_data.vitals.spo2}%")
                if form_data.vitals.respiratory_rate:
                    vitals_info.append(f"RR: {form_data.vitals.respiratory_rate}")
                if vitals_info:
                    context_parts.append(f"\nExtracted Vitals: {', '.join(vitals_info)}")
            if form_data.symptoms:
                context_parts.append(f"\nSymptoms: {', '.join(form_data.symptoms)}")
            if form_data.physical_examination:
                context_parts.append(f"\nPhysical Exam: {form_data.physical_examination}")

        user_prompt = f"""Generate a SOAP note from this clinical encounter:

{chr(10).join(context_parts)}

Return a JSON object with subjective, objective, assessment, and plan sections."""

        try:
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": self.SOAP_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.2,
                max_tokens=1500,
            )

            content = response.choices[0].message.content
            return SOAPNote.model_validate_json(content)

        except Exception as e:
            import traceback
            print(f"SOAP generation error: {e}")
            traceback.print_exc()
            return SOAPNote()

    async def generate_icd_codes(self, transcript: str, soap_note: Optional[SOAPNote] = None) -> list[ICDCode]:
        """Generate ICD-10 code suggestions"""
        if not transcript or len(transcript.strip()) < 20:
            return []

        context = f"Transcript:\n{transcript}"
        if soap_note:
            context += f"\n\nSOAP Note:\n- Subjective: {soap_note.subjective}\n- Objective: {soap_note.objective}\n- Assessment: {soap_note.assessment}\n- Plan: {soap_note.plan}"

        user_prompt = f"""Suggest ICD-10 codes for this clinical encounter:

{context}

Return a JSON object with an array of codes."""

        try:
            response = await self.client.chat.completions.create(
                model="gpt-4o",
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": self.ICD_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.1,
                max_tokens=500,
            )

            content = response.choices[0].message.content
            import json
            data = json.loads(content)
            codes = [ICDCode(**c) for c in data.get("codes", [])]
            return codes

        except Exception as e:
            import traceback
            print(f"ICD code generation error: {e}")
            traceback.print_exc()
            return []
