/**
 * Medical Assistant - WebSocket Client Module
 * Handles real-time communication with the transcription backend
 */

class TranscriptionWebSocket {
    constructor() {
        this.ws = null;
        this.language = 'ar_en';  // Bilingual: Arabic + English
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 1000;
        this.isConnecting = false;

        // Event callbacks
        this.onPartial = null;
        this.onFinal = null;
        this.onFormUpdate = null;
        this.onSuggestionsUpdate = null;
        this.onSoapUpdate = null;
        this.onIcdCodesUpdate = null;
        this.onError = null;
        this.onStatusChange = null;
        this.onDemoComplete = null;
        this.onEndOfUtterance = null;
        this.onAiProcessing = null;
        this.onReasoning = null;
    }

    /**
     * Get WebSocket URL based on current location
     */
    getWebSocketUrl(language) {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.host;
        return `${protocol}//${host}/ws/${language}`;
    }

    /**
     * Connect to the WebSocket server
     */
    async connect(language = 'ar_en') {
        if (this.isConnecting) return;

        this.language = language;
        this.isConnecting = true;

        this.updateStatus('connecting');

        try {
            const url = this.getWebSocketUrl(language);
            console.log('>>> Connecting to WebSocket URL:', url);
            this.ws = new WebSocket(url);

            await new Promise((resolve, reject) => {
                this.ws.onopen = () => {
                    console.log('WebSocket connected');
                    this.reconnectAttempts = 0;
                    this.isConnecting = false;
                    this.updateStatus('connected');
                    resolve();
                };

                this.ws.onerror = (error) => {
                    console.error('WebSocket error:', error);
                    this.isConnecting = false;
                    reject(error);
                };

                this.ws.onclose = (event) => {
                    console.log('WebSocket closed:', event.code, event.reason);
                    this.isConnecting = false;
                    this.handleClose(event);
                };

                this.ws.onmessage = (event) => {
                    this.handleMessage(event);
                };
            });

            return true;
        } catch (error) {
            this.isConnecting = false;
            this.updateStatus('error');
            throw error;
        }
    }

    /**
     * Handle incoming WebSocket messages
     */
    handleMessage(event) {
        try {
            const data = JSON.parse(event.data);
            const now = performance.now();
            if (data.type === 'final') {
                console.log(`[WS ${now.toFixed(1)}ms] Received: ${data.type} - "${data.text?.substring(0, 40)}..."`);
            } else if (data.type !== 'pong') {
                console.log(`[WS ${now.toFixed(1)}ms] Received: ${data.type}`);
            }

            switch (data.type) {
                case 'connected':
                    console.log('Transcription session connected for language:', data.language);
                    if (data.diarization_enabled) {
                        console.log('Speaker diarization enabled');
                    }
                    break;

                case 'partial':
                    if (this.onPartial) {
                        // Pass full data object for diarization support
                        if (data.speaker_role) {
                            this.onPartial({
                                text: data.text,
                                speaker: data.speaker,
                                speaker_role: data.speaker_role,
                                start_time: data.start_time,
                                end_time: data.end_time
                            });
                        } else {
                            this.onPartial(data.text);
                        }
                    }
                    break;

                case 'final':
                    if (this.onFinal) {
                        // Pass full data object for diarization support
                        if (data.speaker_role) {
                            this.onFinal({
                                text: data.text,
                                speaker: data.speaker,
                                speaker_role: data.speaker_role,
                                start_time: data.start_time,
                                end_time: data.end_time
                            });
                        } else {
                            this.onFinal(data.text);
                        }
                    }
                    break;

                case 'form_update':
                    if (this.onFormUpdate) {
                        this.onFormUpdate(data.data);
                    }
                    break;

                case 'suggestions_update':
                    if (this.onSuggestionsUpdate) {
                        this.onSuggestionsUpdate(data.data);
                    }
                    break;

                case 'soap_update':
                    if (this.onSoapUpdate) {
                        this.onSoapUpdate(data.data);
                    }
                    break;

                case 'icd_codes_update':
                    if (this.onIcdCodesUpdate) {
                        this.onIcdCodesUpdate(data.data);
                    }
                    break;

                case 'error':
                    console.error('Server error:', data.message);
                    if (this.onError) {
                        this.onError(data.message);
                    }
                    break;

                case 'reset_complete':
                    console.log('Transcript reset complete');
                    break;

                case 'paused':
                    console.log('Transcription paused');
                    break;

                case 'resumed':
                    console.log('Transcription resumed');
                    break;

                case 'patient_set':
                    console.log('Patient name set:', data.name);
                    break;

                case 'pong':
                    // Heartbeat response
                    break;

                case 'demo_complete':
                    console.log('Demo complete');
                    if (this.onDemoComplete) {
                        this.onDemoComplete();
                    }
                    break;

                case 'end_of_utterance':
                    console.log('End of utterance at', data.end_time);
                    if (this.onEndOfUtterance) {
                        this.onEndOfUtterance(data.end_time);
                    }
                    break;

                case 'ai_processing':
                    console.log('AI processing:', data.status);
                    if (this.onAiProcessing) {
                        this.onAiProcessing(data.status);
                    }
                    break;

                case 'reasoning':
                    console.log('AI reasoning:', data.text);
                    if (this.onReasoning) {
                        this.onReasoning(data.text, data.icon || 'info');
                    }
                    break;

                default:
                    console.log('Unknown message type:', data.type);
            }
        } catch (error) {
            console.error('Error parsing message:', error);
        }
    }

    /**
     * Handle WebSocket close event
     */
    handleClose(event) {
        this.updateStatus('disconnected');

        // Attempt reconnection if not a normal close
        if (event.code !== 1000 && this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

            console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

            setTimeout(() => {
                this.connect(this.language);
            }, delay);
        }
    }

    /**
     * Update connection status
     */
    updateStatus(status) {
        if (this.onStatusChange) {
            this.onStatusChange(status);
        }
    }

    /**
     * Start transcription session
     */
    startSession() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'start' }));
        }
    }

    /**
     * Stop transcription session
     */
    stopSession() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'stop' }));
        }
    }

    /**
     * Pause transcription session
     */
    pauseSession() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'pause' }));
        }
    }

    /**
     * Resume transcription session
     */
    resumeSession() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'resume' }));
        }
    }

    /**
     * Reset transcript buffer
     */
    resetTranscript() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'reset' }));
        }
    }

    /**
     * Set patient name
     */
    setPatient(name) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'set_patient', name }));
        }
    }

    /**
     * Request SOAP note generation
     */
    generateSOAP() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'generate_soap' }));
        }
    }

    /**
     * Send audio data
     */
    sendAudio(audioBuffer) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(audioBuffer);
        }
    }

    /**
     * Send ping for keepalive
     */
    ping() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'ping' }));
        }
    }

    /**
     * Disconnect from server
     */
    disconnect() {
        if (this.ws) {
            this.ws.close(1000, 'Client disconnect');
            this.ws = null;
        }
    }

    /**
     * Change language (reconnects with new language)
     */
    async changeLanguage(language) {
        if (language === this.language && this.ws?.readyState === WebSocket.OPEN) {
            return;
        }

        this.disconnect();
        await this.connect(language);
    }

    /**
     * Check if connected
     */
    isConnected() {
        return this.ws && this.ws.readyState === WebSocket.OPEN;
    }
}


/**
 * Demo WebSocket Client
 * Connects to demo endpoint for testing without real transcription
 */
class DemoWebSocket extends TranscriptionWebSocket {
    getWebSocketUrl() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.host;
        return `${protocol}//${host}/ws/demo`;
    }

    startDemo() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'start_demo' }));
        }
    }

    generateSOAP() {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type: 'generate_soap' }));
        }
    }
}

// Export for use in other modules
window.TranscriptionWebSocket = TranscriptionWebSocket;
window.DemoWebSocket = DemoWebSocket;
