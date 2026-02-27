/**
 * Medical Assistant - Main Application
 * Orchestrates audio capture, WebSocket communication, and UI updates
 */

class MedicalAssistantApp {
    constructor() {
        // Components
        this.audio = new AudioCapture();
        this.ws = new TranscriptionWebSocket();
        this.demoWs = new DemoWebSocket();
        this.visualizer = null;

        // State
        this.isRecording = false;
        this.isPaused = false;
        this.isDemoMode = false;
        this.currentLanguage = 'ar_en';  // Bilingual: Arabic + English
        this.transcriptSegments = [];

        // Timer state
        this.timerInterval = null;
        this.elapsedSeconds = 0;

        // DOM Elements
        this.elements = {
            // Header
            patientName: document.getElementById('patientName'),
            recordingTimer: document.getElementById('recordingTimer'),

            // Controls
            recordBtn: document.getElementById('recordBtn'),
            pauseBtn: document.getElementById('pauseBtn'),
            stopBtn: document.getElementById('stopBtn'),
            resetBtn: document.getElementById('resetBtn'),
            demoBtn: document.getElementById('demoBtn'),

            // Status
            connectionStatus: document.getElementById('connectionStatus'),

            // Transcript
            transcriptContainer: document.getElementById('transcriptContainer'),
            transcriptContent: document.getElementById('transcriptContent'),
            partialTranscript: document.getElementById('partialTranscript'),
            visualizerCanvas: document.getElementById('visualizerCanvas'),

            // Form fields
            vitalBP: document.getElementById('vitalBP'),
            vitalPulse: document.getElementById('vitalPulse'),
            vitalTemp: document.getElementById('vitalTemp'),
            vitalRespRate: document.getElementById('vitalRespRate'),
            vitalSpO2: document.getElementById('vitalSpO2'),
            vitalRhythm: document.getElementById('vitalRhythm'),
            physicalExam: document.getElementById('physicalExam'),
            symptomsTags: document.getElementById('symptomsTags'),
            symptomsInput: document.getElementById('symptomsInput'),
            otherDetails: document.getElementById('otherDetails'),
            actionSelect: document.getElementById('actionSelect'),
            dischargeRecommended: document.getElementById('dischargeRecommended'),

            // Suggestions
            questionsContent: document.getElementById('questionsContent'),
            diagnosesContent: document.getElementById('diagnosesContent'),
            testsContent: document.getElementById('testsContent'),
            medicationsContent: document.getElementById('medicationsContent'),
            referralsContent: document.getElementById('referralsContent'),

            // New features
            timeSaved: document.getElementById('timeSaved'),
            completenessFill: document.getElementById('completenessFill'),
            completenessText: document.getElementById('completenessText'),
            generateSoapBtn: document.getElementById('generateSoapBtn'),
            soapNoteContent: document.getElementById('soapNoteContent'),
            icdCodesContent: document.getElementById('icdCodesContent'),
            aiShimmerBar: document.getElementById('aiShimmerBar'),
            reasoningStream: document.getElementById('reasoningStream'),
            reasoningContent: document.getElementById('reasoningContent'),
            reasoningClose: document.getElementById('reasoningClose'),
        };

        this.init();
    }

    async init() {
        // Set up event listeners
        this.setupEventListeners();

        // Set up WebSocket callbacks
        this.setupWebSocketCallbacks();

        // Set up suggestion group toggles
        this.setupSuggestionGroups();

        // Set up visualizer immediately (shows idle state)
        this.visualizer = new AudioVisualizer(
            this.elements.visualizerCanvas,
            null
        );

        // Initialize audio
        try {
            await this.audio.initialize();
            this.elements.recordBtn.disabled = false;

            // Connect analyser to visualizer
            this.visualizer.setAnalyser(this.audio.getAnalyser());
        } catch (error) {
            console.error('Failed to initialize audio:', error);
            this.showError('Microphone access denied. Please allow microphone access to use transcription.');
        }

        // Connect to WebSocket
        try {
            await this.ws.connect(this.currentLanguage);
        } catch (error) {
            console.error('Failed to connect to WebSocket:', error);
        }
    }

    setupEventListeners() {
        // Record button
        this.elements.recordBtn.addEventListener('click', () => this.startRecording());

        // Pause button (toggles between pause and resume)
        this.elements.pauseBtn.addEventListener('click', () => {
            if (this.isPaused) {
                this.resumeRecording();
            } else {
                this.pauseRecording();
            }
        });

        // Stop button
        this.elements.stopBtn.addEventListener('click', () => this.stopRecording());

        // Reset button
        this.elements.resetBtn.addEventListener('click', () => this.resetAll());

        // Demo button
        this.elements.demoBtn.addEventListener('click', () => this.runDemo());

        // Patient name input
        this.elements.patientName.addEventListener('change', (e) => {
            this.ws.setPatient(e.target.value);
        });

        // Generate SOAP note button
        this.elements.generateSoapBtn.addEventListener('click', () => this.generateSOAPNote());

        // Symptoms input
        this.elements.symptomsInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && e.target.value.trim()) {
                this.addSymptomTag(e.target.value.trim());
                e.target.value = '';
            }
        });

        // Reasoning stream close button
        if (this.elements.reasoningClose) {
            this.elements.reasoningClose.addEventListener('click', () => {
                this.elements.reasoningStream?.classList.remove('active');
            });
        }
    }

    setupWebSocketCallbacks() {
        // Partial transcript (with diarization)
        this.ws.onPartial = (data) => {
            if (typeof data === 'object' && data.speaker_role) {
                // Diarized partial
                this.showDiarizedPartial(data);
            } else if (typeof data === 'object' && data.text) {
                this.elements.partialTranscript.textContent = data.text;
            } else {
                this.elements.partialTranscript.textContent = data;
            }
        };

        // Final transcript (with diarization)
        this.ws.onFinal = (data) => {
            const now = performance.now();
            console.log(`[${now.toFixed(1)}ms] Received final transcript:`, typeof data === 'object' ? data.text?.substring(0, 30) : data?.substring(0, 30));

            if (typeof data === 'object' && data.speaker_role) {
                // Diarized final
                this.addDiarizedSegment(data);
            } else if (typeof data === 'object' && data.text) {
                this.addTranscriptSegment(data.text);
            } else {
                this.addTranscriptSegment(data);
            }
            this.elements.partialTranscript.innerHTML = '';
            console.log(`[${performance.now().toFixed(1)}ms] DOM updated`);
        };

        // Form update
        this.ws.onFormUpdate = (data) => {
            this.updateFormFields(data);
        };

        // Suggestions update
        this.ws.onSuggestionsUpdate = (data) => {
            this.updateSuggestions(data);
        };

        // SOAP note update
        this.ws.onSoapUpdate = (data) => {
            this.displaySOAPNote(data);
        };

        // ICD codes update
        this.ws.onIcdCodesUpdate = (data) => {
            this.displayICDCodes(data);
        };

        // Error
        this.ws.onError = (message) => {
            this.showError(message);
        };

        // Status change
        this.ws.onStatusChange = (status) => {
            this.updateConnectionStatus(status);
        };

        // Same callbacks for demo WebSocket
        this.demoWs.onPartial = this.ws.onPartial;
        this.demoWs.onFinal = this.ws.onFinal;
        this.demoWs.onFormUpdate = this.ws.onFormUpdate;
        this.demoWs.onSuggestionsUpdate = this.ws.onSuggestionsUpdate;
        this.demoWs.onSoapUpdate = this.ws.onSoapUpdate;
        this.demoWs.onIcdCodesUpdate = this.ws.onIcdCodesUpdate;
        this.demoWs.onError = this.ws.onError;
        this.demoWs.onStatusChange = this.ws.onStatusChange;

        // Demo complete callback - stop the timer but stay in demo mode
        this.demoWs.onDemoComplete = () => {
            this.stopTimer();
            // Keep isDemoMode = true so SOAP generation uses demo websocket
        };

        // AI processing indicator
        this.ws.onAiProcessing = (status, reasoning) => {
            this.handleAiProcessing(status, reasoning);
        };
        this.demoWs.onAiProcessing = (status, reasoning) => {
            this.handleAiProcessing(status, reasoning);
        };

        // Reasoning stream updates
        this.ws.onReasoning = (text, icon) => {
            this.addReasoningItem(text, icon);
        };
        this.demoWs.onReasoning = (text, icon) => {
            this.addReasoningItem(text, icon);
        };
    }

    handleAiProcessing(status, reasoning) {
        console.log('handleAiProcessing called:', status);
        const isProcessing = status === 'start';

        // Toggle shimmer bar
        if (this.elements.aiShimmerBar) {
            this.elements.aiShimmerBar.classList.toggle('active', isProcessing);
            console.log('Shimmer bar active:', isProcessing);
        } else {
            console.error('aiShimmerBar element not found!');
        }

        // Toggle reasoning stream
        if (this.elements.reasoningStream) {
            this.elements.reasoningStream.classList.toggle('active', isProcessing);
            console.log('Reasoning stream active:', isProcessing);
        } else {
            console.error('reasoningStream element not found!');
        }

        // Clear reasoning content when starting
        if (isProcessing && this.elements.reasoningContent) {
            this.elements.reasoningContent.innerHTML = '';
        }

        // Toggle Generate button state
        if (this.elements.generateSoapBtn) {
            if (isProcessing) {
                this.elements.generateSoapBtn.classList.add('synthesizing');
                this.elements.generateSoapBtn.innerHTML = `
                    <span class="orb">
                        <span class="orb-pulse"></span>
                        <span class="orb-core"></span>
                    </span>
                    <span>Synthesizing...</span>
                `;
            } else {
                this.elements.generateSoapBtn.classList.remove('synthesizing');
                this.elements.generateSoapBtn.innerHTML = `
                    <span class="material-symbols-outlined">stars</span>
                    <span>Generate Note</span>
                `;
            }
        }
    }

    addReasoningItem(text, icon = 'info') {
        console.log('Adding reasoning item:', text, icon);
        if (!this.elements.reasoningContent) {
            console.error('reasoningContent element not found!');
            return;
        }

        const item = document.createElement('div');
        item.className = 'reasoning-item';
        item.innerHTML = `
            <span class="material-symbols-outlined">${icon}</span>
            <p>${text}</p>
        `;

        this.elements.reasoningContent.appendChild(item);
        console.log('Reasoning item added, total items:', this.elements.reasoningContent.children.length);

        // Auto-scroll to bottom
        this.elements.reasoningContent.scrollTop = this.elements.reasoningContent.scrollHeight;
    }

    setupSuggestionGroups() {
        const groups = document.querySelectorAll('.suggestion-group');
        groups.forEach(group => {
            const header = group.querySelector('.suggestion-group-header');
            header.addEventListener('click', () => {
                group.classList.toggle('expanded');
            });
        });
    }

    // ==================== RECORDING CONTROLS ====================

    async startRecording() {
        if (this.isRecording) return;

        try {
            // Ensure WebSocket is connected
            if (!this.ws.isConnected()) {
                await this.ws.connect(this.currentLanguage);
            }

            // Start transcription session
            this.ws.startSession();

            // Start audio capture
            this.audio.start((audioBuffer) => {
                if (!this.isPaused) {
                    this.ws.sendAudio(audioBuffer);
                }
            });

            // Start visualizer
            if (this.visualizer) {
                this.visualizer.start();
            }

            // Start timer
            this.startTimer();

            this.isRecording = true;
            this.isPaused = false;
            this.isDemoMode = false;  // Clear demo mode when starting real recording
            this.updateRecordingUI();
        } catch (error) {
            console.error('Failed to start recording:', error);
            this.showError('Failed to start recording. Please try again.');
        }
    }

    pauseRecording() {
        if (!this.isRecording || this.isPaused) return;

        this.isPaused = true;
        this.ws.pauseSession();
        this.pauseTimer();
        this.updateRecordingUI();
    }

    resumeRecording() {
        if (!this.isRecording || !this.isPaused) return;

        this.isPaused = false;
        this.ws.resumeSession();
        this.startTimer();
        this.updateRecordingUI();
    }

    stopRecording() {
        if (!this.isRecording) return;

        // Stop audio capture
        this.audio.stop();

        // Stop transcription session
        this.ws.stopSession();

        // Stop visualizer
        if (this.visualizer) {
            this.visualizer.stop();
        }

        // Stop timer
        this.stopTimer();

        this.isRecording = false;
        this.isPaused = false;
        this.updateRecordingUI();
    }

    resetAll() {
        // Stop recording if active
        if (this.isRecording) {
            this.stopRecording();
        }

        // Reset timer
        this.resetTimer();

        // Reset mode flags
        this.isDemoMode = false;

        // Clear transcript
        this.transcriptSegments = [];
        this.currentSpeakerRole = null;
        this.currentSegmentElement = null;
        this.elements.transcriptContent.innerHTML = '<p class="transcript-placeholder">Transcript will appear here with speaker labels...</p>';
        this.elements.partialTranscript.innerHTML = '';

        // Clear form
        this.clearFormFields();

        // Clear suggestions
        this.clearSuggestions();

        // Clear new features (time saved, completeness, SOAP, ICD)
        this.clearNewFeatures();

        // Reset WebSocket buffer
        this.ws.resetTranscript();
    }

    // ==================== TIMER ====================

    startTimer() {
        if (this.timerInterval) return;

        this.timerInterval = setInterval(() => {
            this.elapsedSeconds++;
            this.updateTimerDisplay();
        }, 1000);

        this.elements.recordingTimer.classList.add('active');
        this.elements.recordingTimer.classList.remove('paused');
    }

    pauseTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
        this.elements.recordingTimer.classList.remove('active');
        this.elements.recordingTimer.classList.add('paused');
    }

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
        this.elements.recordingTimer.classList.remove('active', 'paused');
    }

    resetTimer() {
        this.stopTimer();
        this.elapsedSeconds = 0;
        this.updateTimerDisplay();
    }

    updateTimerDisplay() {
        const hours = Math.floor(this.elapsedSeconds / 3600);
        const minutes = Math.floor((this.elapsedSeconds % 3600) / 60);
        const seconds = this.elapsedSeconds % 60;

        const display = this.elements.recordingTimer.querySelector('.timer-display');
        display.textContent = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }

    // ==================== DEMO MODE ====================

    async runDemo() {
        // Stop any active recording
        if (this.isRecording) {
            this.stopRecording();
        }

        // Reset state
        this.resetAll();

        try {
            // Connect to demo endpoint
            await this.demoWs.connect();

            // Set demo mode flag
            this.isDemoMode = true;

            // Start demo timer
            this.startTimer();

            // Start demo
            this.demoWs.startDemo();
        } catch (error) {
            console.error('Failed to run demo:', error);
            this.showError('Failed to run demo. Please ensure the server is running.');
        }
    }

    // ==================== TRANSCRIPT DISPLAY ====================

    // Track current speaker for grouping
    currentSpeakerRole = null;
    currentSegmentElement = null;

    formatTimestamp(seconds) {
        const date = new Date();
        date.setSeconds(date.getSeconds() - (this.elapsedSeconds - seconds));
        return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
    }

    showDiarizedPartial(data) {
        const roleLabel = data.speaker_role === 'doctor' ? 'DOCTOR' :
                         data.speaker_role === 'patient' ? 'PATIENT' : 'SPEAKER';
        const initials = data.speaker_role === 'doctor' ? 'DR' :
                        data.speaker_role === 'patient' ? 'PT' : 'SP';

        // Show typing indicator (3 bouncing dots) instead of partial text
        this.elements.partialTranscript.innerHTML = `
            <div class="transcript-segment typing speaker-${data.speaker_role}">
                <div class="speaker-avatar ${data.speaker_role}">${initials}</div>
                <div class="segment-content">
                    <div class="segment-header">
                        <span class="speaker-label">${roleLabel}</span>
                        <span class="segment-time">now</span>
                    </div>
                    <div class="typing-indicator">
                        <span class="dot"></span>
                        <span class="dot"></span>
                        <span class="dot"></span>
                    </div>
                </div>
            </div>
        `;
    }

    addDiarizedSegment(data) {
        // Remove placeholder if present
        const placeholder = this.elements.transcriptContent.querySelector('.transcript-placeholder');
        if (placeholder) {
            placeholder.remove();
        }

        // Store segment data
        this.transcriptSegments.push({
            text: data.text,
            speaker: data.speaker,
            speaker_role: data.speaker_role,
            start_time: data.start_time,
            end_time: data.end_time
        });

        const roleLabel = data.speaker_role === 'doctor' ? 'DOCTOR' :
                         data.speaker_role === 'patient' ? 'PATIENT' : 'SPEAKER';
        const initials = data.speaker_role === 'doctor' ? 'DR' :
                        data.speaker_role === 'patient' ? 'PT' : 'SP';
        const timestamp = this.formatTimestamp(data.start_time || 0);

        // Check if same speaker as current segment - append to existing
        // Same speaker — append to existing segment
        if (this.currentSpeakerRole === data.speaker_role && this.currentSegmentElement) {
            // Append text to existing segment
            const textEl = this.currentSegmentElement.querySelector('.segment-text');
            textEl.textContent += ' ' + data.text;
        } else {
            // New speaker - create new segment
            const segment = document.createElement('div');
            segment.className = `transcript-segment speaker-${data.speaker_role}`;
            segment.innerHTML = `
                <div class="speaker-avatar ${data.speaker_role}">${initials}</div>
                <div class="segment-content">
                    <div class="segment-header">
                        <span class="speaker-label">${roleLabel}</span>
                        <span class="segment-time">${timestamp}</span>
                    </div>
                    <p class="segment-text">${data.text}</p>
                </div>
            `;

            this.elements.transcriptContent.appendChild(segment);

            // Update current speaker tracking
            this.currentSpeakerRole = data.speaker_role;
            this.currentSegmentElement = segment;
        }

        // Scroll to bottom
        this.elements.transcriptContainer.scrollTop = this.elements.transcriptContainer.scrollHeight;
    }

    addTranscriptSegment(text) {
        // Remove placeholder if present
        const placeholder = this.elements.transcriptContent.querySelector('.transcript-placeholder');
        if (placeholder) {
            placeholder.remove();
        }

        // Add segment
        this.transcriptSegments.push({ text });

        // Check if we can append to current unknown segment
        if (this.currentSpeakerRole === 'unknown' && this.currentSegmentElement) {
            const textSpan = this.currentSegmentElement.querySelector('.segment-text');
            textSpan.textContent += ' ' + text;
        } else {
            // Create new segment
            const segment = document.createElement('div');
            segment.className = 'transcript-segment speaker-unknown';
            segment.innerHTML = `<span class="segment-text">${text}</span>`;
            this.elements.transcriptContent.appendChild(segment);

            this.currentSpeakerRole = 'unknown';
            this.currentSegmentElement = segment;
        }

        // Scroll to bottom
        this.elements.transcriptContainer.scrollTop = this.elements.transcriptContainer.scrollHeight;
    }

    // ==================== FORM UPDATES ====================

    updateFormFields(data) {
        // Update vitals
        if (data.vitals) {
            this.updateField(this.elements.vitalBP, data.vitals.blood_pressure);
            this.updateField(this.elements.vitalPulse, data.vitals.pulse);
            this.updateField(this.elements.vitalTemp, data.vitals.temperature);
            this.updateField(this.elements.vitalRespRate, data.vitals.respiratory_rate);
            this.updateField(this.elements.vitalSpO2, data.vitals.spo2);
            this.updateField(this.elements.vitalRhythm, data.vitals.rhythm);

            // Check for abnormal values
            this.checkVitalAbnormality('vitalPulse', data.vitals.pulse, 60, 100);
            this.checkVitalAbnormality('vitalSpO2', data.vitals.spo2, 95, 100);
            this.checkVitalAbnormality('vitalRespRate', data.vitals.respiratory_rate, 12, 20);
        }

        // Update other fields
        this.updateField(this.elements.physicalExam, data.physical_examination);
        this.updateField(this.elements.otherDetails, data.other_details);

        // Update symptoms
        if (data.symptoms && data.symptoms.length > 0) {
            this.updateSymptoms(data.symptoms);
        }

        // Update selects
        this.updateSelectField(this.elements.actionSelect, data.action);

        // Update checkbox
        if (data.discharge_recommended !== null && data.discharge_recommended !== undefined) {
            this.elements.dischargeRecommended.checked = data.discharge_recommended;
        }

        // Update completeness score
        this.updateCompletenessScore();
    }

    updateField(element, value) {
        if (!element || value === null || value === undefined) return;
        element.value = value;
    }

    updateSelectField(element, value) {
        if (!element || !value) return;

        // Find matching option
        const options = Array.from(element.options);
        const match = options.find(opt =>
            opt.value.toLowerCase() === value.toLowerCase() ||
            opt.textContent.toLowerCase() === value.toLowerCase()
        );

        if (match) {
            element.value = match.value;
        } else {
            element.value = value;
        }
    }

    updateSymptoms(symptoms) {
        // Clear existing tags
        this.elements.symptomsTags.innerHTML = '';

        // Add new symptoms
        symptoms.forEach(symptom => {
            this.addSymptomTag(symptom);
        });
    }

    addSymptomTag(text) {
        const tag = document.createElement('span');
        tag.className = 'symptom-tag';
        tag.innerHTML = `
            ${text}
            <button type="button" onclick="this.parentElement.remove()">&times;</button>
        `;
        this.elements.symptomsTags.appendChild(tag);
    }

    checkVitalAbnormality(elementId, value, min, max) {
        const element = document.getElementById(elementId);
        const container = element?.closest('.vital-item');

        if (container && value !== null && value !== undefined) {
            if (value < min || value > max) {
                container.classList.add('abnormal');
            } else {
                container.classList.remove('abnormal');
            }
        }
    }

    clearFormFields() {
        // Clear vitals
        if (this.elements.vitalBP) this.elements.vitalBP.value = '';
        if (this.elements.vitalPulse) this.elements.vitalPulse.value = '';
        if (this.elements.vitalTemp) this.elements.vitalTemp.value = '';
        if (this.elements.vitalRespRate) this.elements.vitalRespRate.value = '';
        if (this.elements.vitalSpO2) this.elements.vitalSpO2.value = '';
        if (this.elements.vitalRhythm) this.elements.vitalRhythm.value = '';

        // Clear other fields
        if (this.elements.physicalExam) this.elements.physicalExam.value = '';
        if (this.elements.otherDetails) this.elements.otherDetails.value = '';
        if (this.elements.symptomsTags) this.elements.symptomsTags.innerHTML = '';
        if (this.elements.actionSelect) this.elements.actionSelect.value = '';
        if (this.elements.dischargeRecommended) this.elements.dischargeRecommended.checked = false;

        // Remove abnormal indicators
        document.querySelectorAll('.vital-item.abnormal').forEach(el => {
            el.classList.remove('abnormal');
        });
    }

    // ==================== SUGGESTIONS ====================

    updateSuggestions(data) {
        this.updateSuggestionGroup('questions', data.questions_to_ask || []);
        this.updateSuggestionGroup('diagnoses', data.potential_diagnoses || []);
        this.updateSuggestionGroup('tests', data.tests_to_consider || []);
        this.updateSuggestionGroup('medications', data.medications_to_consider || []);
        this.updateSuggestionGroup('referrals', data.referrals || []);
    }

    updateSuggestionGroup(groupName, items) {
        const contentEl = this.elements[`${groupName}Content`];

        if (!contentEl) return;

        // Update content
        if (items.length === 0) {
            contentEl.innerHTML = '<div class="suggestion-empty">No suggestions yet</div>';
        } else {
            contentEl.innerHTML = items.map(item => `
                <div class="suggestion-item priority-${item.priority || 'normal'}">
                    <div class="suggestion-text">${item.text}</div>
                    ${item.rationale ? `<div class="suggestion-rationale">${item.rationale}</div>` : ''}
                </div>
            `).join('');
        }
    }

    clearSuggestions() {
        ['questions', 'diagnoses', 'tests', 'medications', 'referrals'].forEach(group => {
            const contentEl = this.elements[`${group}Content`];
            if (contentEl) {
                contentEl.innerHTML = '<div class="suggestion-empty">No suggestions yet</div>';
            }
        });
    }

    // ==================== UI UPDATES ====================

    updateConnectionStatus(status) {
        const statusEl = this.elements.connectionStatus;
        const textEl = statusEl.querySelector('.status-text');

        statusEl.className = 'connection-status ' + status;

        const statusTexts = {
            connecting: 'Connecting...',
            connected: 'Connected',
            disconnected: 'Disconnected',
            error: 'Error'
        };

        textEl.textContent = statusTexts[status] || status;
    }

    updateRecordingUI() {
        const { recordBtn, pauseBtn, stopBtn } = this.elements;
        const pauseIcon = pauseBtn.querySelector('.material-symbols-outlined');

        if (this.isRecording) {
            // Recording or paused - disable record, enable pause/stop
            recordBtn.disabled = true;
            pauseBtn.disabled = false;
            stopBtn.disabled = false;

            if (this.isPaused) {
                // Paused state - show play icon on pause button
                pauseIcon.textContent = 'play_arrow';
                pauseBtn.title = 'Resume';
            } else {
                // Active recording state - show pause icon
                pauseIcon.textContent = 'pause';
                pauseBtn.title = 'Pause';
            }
        } else {
            // Idle state - enable record, disable pause/stop
            recordBtn.disabled = false;
            pauseBtn.disabled = true;
            stopBtn.disabled = true;
            pauseIcon.textContent = 'pause';
            pauseBtn.title = 'Pause';
        }
    }

    showError(message) {
        // For now, just log to console
        // Could be enhanced with a toast notification system
        console.error('Medical Assistant Error:', message);
        alert(message);
    }

    // ==================== TIME SAVED ====================

    updateTimeSaved() {
        // Calculate time saved: AI takes ~2 min vs manual ~15 min for typical note
        // Rough estimate: 13 minutes saved per complete form
        const completeness = this.calculateCompleteness();
        const minutesSaved = Math.round((completeness / 100) * 13);

        const display = this.elements.timeSaved.querySelector('.time-saved-value');
        display.textContent = `${minutesSaved} min saved`;

        // Highlight animation
        this.elements.timeSaved.classList.add('highlight');
        setTimeout(() => {
            this.elements.timeSaved.classList.remove('highlight');
        }, 500);
    }

    // ==================== COMPLETENESS SCORE ====================

    calculateCompleteness() {
        const fields = [
            this.elements.vitalBP.value,
            this.elements.vitalPulse.value,
            this.elements.vitalTemp.value,
            this.elements.vitalSpO2.value,
            this.elements.physicalExam.value,
            this.elements.symptomsTags.children.length > 0,
            this.elements.otherDetails.value,
            this.elements.actionSelect.value,
        ];

        const filledCount = fields.filter(f => f).length;
        return Math.round((filledCount / fields.length) * 100);
    }

    updateCompletenessScore() {
        const score = this.calculateCompleteness();

        this.elements.completenessFill.style.width = `${score}%`;
        this.elements.completenessText.textContent = `${score}%`;

        // Update time saved when completeness changes
        this.updateTimeSaved();
    }

    // ==================== SOAP NOTE ====================

    generateSOAPNote() {
        if (this.transcriptSegments.length === 0) {
            alert('Please record or run demo first to generate SOAP note.');
            return;
        }

        // Show loading state
        this.elements.generateSoapBtn.disabled = true;
        this.elements.generateSoapBtn.classList.add('loading');
        if (this.elements.soapNoteContent) {
            this.elements.soapNoteContent.innerHTML = '<p class="soap-placeholder">Generating SOAP note...</p>';
        }

        // Request SOAP note from server (use demo or regular WebSocket)
        if (this.isDemoMode) {
            this.demoWs.generateSOAP();
        } else {
            this.ws.generateSOAP();
        }
    }

    displaySOAPNote(data) {
        this.elements.generateSoapBtn.disabled = false;
        this.elements.generateSoapBtn.classList.remove('loading');

        if (!this.elements.soapNoteContent) return;

        if (!data || (!data.subjective && !data.objective && !data.assessment && !data.plan)) {
            this.elements.soapNoteContent.innerHTML = '<p class="soap-placeholder">Unable to generate SOAP note.</p>';
            return;
        }

        this.elements.soapNoteContent.innerHTML = `
            <div class="soap-section">
                <div class="soap-section-title">S - Subjective</div>
                <div class="soap-section-content">${data.subjective || 'N/A'}</div>
            </div>
            <div class="soap-section">
                <div class="soap-section-title">O - Objective</div>
                <div class="soap-section-content">${data.objective || 'N/A'}</div>
            </div>
            <div class="soap-section">
                <div class="soap-section-title">A - Assessment</div>
                <div class="soap-section-content">${data.assessment || 'N/A'}</div>
            </div>
            <div class="soap-section">
                <div class="soap-section-title">P - Plan</div>
                <div class="soap-section-content">${data.plan || 'N/A'}</div>
            </div>
        `;
    }

    // ==================== ICD-10 CODES ====================

    displayICDCodes(codes) {
        if (!this.elements.icdCodesContent) return;

        if (!codes || codes.length === 0) {
            this.elements.icdCodesContent.innerHTML = '<p class="icd-placeholder">No codes suggested yet...</p>';
            return;
        }

        this.elements.icdCodesContent.innerHTML = codes.map(code => {
            const confidencePercent = Math.round(code.confidence * 100);
            return `
                <div class="icd-code-item">
                    <span class="icd-code">${code.code}</span>
                    <span class="icd-description">${code.description}</span>
                    <span class="icd-confidence ${confidencePercent >= 80 ? 'high' : ''}">${confidencePercent}%</span>
                </div>
            `;
        }).join('');
    }

    clearNewFeatures() {
        // Reset time saved
        const timeSavedDisplay = this.elements.timeSaved?.querySelector('.time-saved-value');
        if (timeSavedDisplay) timeSavedDisplay.textContent = '0 min saved';

        // Reset completeness
        if (this.elements.completenessFill) this.elements.completenessFill.style.width = '0%';
        if (this.elements.completenessText) this.elements.completenessText.textContent = '0%';

        // Reset SOAP note
        if (this.elements.soapNoteContent) {
            this.elements.soapNoteContent.innerHTML = '<p class="soap-placeholder">Click "Generate" after recording to create SOAP note...</p>';
        }
        if (this.elements.generateSoapBtn) {
            this.elements.generateSoapBtn.disabled = false;
            this.elements.generateSoapBtn.classList.remove('loading');
        }

        // Reset ICD codes
        if (this.elements.icdCodesContent) {
            this.elements.icdCodesContent.innerHTML = '<p class="icd-placeholder">Click "Generate Note" to suggest ICD-10 codes</p>';
        }
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.app = new MedicalAssistantApp();
});
