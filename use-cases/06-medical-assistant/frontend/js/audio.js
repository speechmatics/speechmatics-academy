/**
 * Medical Assistant - Audio Capture Module
 * Handles microphone access and audio processing for real-time transcription
 * Uses AudioWorklet API (modern replacement for deprecated ScriptProcessorNode)
 */

class AudioCapture {
    constructor() {
        this.stream = null;
        this.audioContext = null;
        this.workletNode = null;
        this.source = null;
        this.analyser = null;
        this.isRecording = false;
        this.onAudioData = null;

        // Audio settings matching Speechmatics requirements
        this.sampleRate = 16000;
    }

    /**
     * Request microphone permission and set up audio processing
     */
    async initialize() {
        try {
            // Request microphone access
            this.stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    channelCount: 1,
                    sampleRate: this.sampleRate,
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });

            // Create audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: this.sampleRate
            });

            // Load AudioWorklet processor module
            await this.audioContext.audioWorklet.addModule('/js/pcm-processor.js');

            // Create source from stream
            this.source = this.audioContext.createMediaStreamSource(this.stream);

            // Create analyser for visualization
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = 256;
            this.source.connect(this.analyser);

            // Create AudioWorklet node
            this.workletNode = new AudioWorkletNode(this.audioContext, 'pcm-processor');

            // Receive PCM data from the worklet thread
            this.workletNode.port.onmessage = (event) => {
                if (this.isRecording && this.onAudioData) {
                    this.onAudioData(event.data);
                }
            };

            return true;
        } catch (error) {
            console.error('Failed to initialize audio:', error);
            throw error;
        }
    }

    /**
     * Start recording
     */
    start(onAudioData) {
        if (!this.audioContext) {
            throw new Error('Audio not initialized. Call initialize() first.');
        }

        this.onAudioData = onAudioData;

        // Resume audio context if suspended
        if (this.audioContext.state === 'suspended') {
            this.audioContext.resume();
        }

        // Connect source → worklet → destination
        this.source.connect(this.workletNode);
        this.workletNode.connect(this.audioContext.destination);

        this.isRecording = true;
    }

    /**
     * Stop recording
     */
    stop() {
        this.isRecording = false;

        if (this.workletNode) {
            this.workletNode.disconnect();
        }
    }

    /**
     * Get analyser for visualization
     */
    getAnalyser() {
        return this.analyser;
    }

    /**
     * Clean up resources
     */
    destroy() {
        this.stop();

        if (this.stream) {
            this.stream.getTracks().forEach(track => track.stop());
        }

        if (this.audioContext) {
            this.audioContext.close();
        }

        this.stream = null;
        this.audioContext = null;
        this.workletNode = null;
        this.source = null;
        this.analyser = null;
    }
}


/**
 * Audio Visualizer
 * Creates a visual representation of audio input with rounded bars
 */
class AudioVisualizer {
    constructor(canvas, analyser) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.analyser = analyser;
        this.isActive = false;
        this.animationFrame = null;

        // Bar configuration
        this.barCount = 24;
        this.barWidth = 4;
        this.barGap = 4;
        this.barColor = '#3B82F6'; // Blue matching the design
        this.minBarHeight = 12;

        // Set canvas size and draw idle after DOM is ready
        window.addEventListener('resize', () => {
            this.resize();
            if (!this.isActive) this.drawIdleBars();
        });

        // Multiple attempts to ensure canvas is ready
        this.initCanvas();
    }

    initCanvas() {
        // Try immediately
        this.resize();
        this.drawIdleBars();

        // Try again after a short delay (DOM might not be ready)
        setTimeout(() => {
            this.resize();
            this.drawIdleBars();
        }, 100);

        // And once more after page fully loads
        window.addEventListener('load', () => {
            this.resize();
            this.drawIdleBars();
        });
    }

    resize() {
        const parent = this.canvas.parentElement;
        // Get computed dimensions to ensure we have actual pixel values
        const styles = window.getComputedStyle(parent);
        const width = parseFloat(styles.width) - parseFloat(styles.paddingLeft) - parseFloat(styles.paddingRight);
        const height = parseFloat(styles.height) - parseFloat(styles.paddingTop) - parseFloat(styles.paddingBottom);

        this.canvas.width = width > 0 ? width : 300;
        this.canvas.height = height > 0 ? height : 64;
    }

    start() {
        this.isActive = true;
        this.draw();
    }

    stop() {
        this.isActive = false;
        if (this.animationFrame) {
            cancelAnimationFrame(this.animationFrame);
        }
        // Show idle bars when stopped instead of empty
        this.drawIdleBars();
    }

    clear() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        // Show idle bars after clearing
        this.drawIdleBars();
    }

    draw() {
        if (!this.isActive) return;

        this.animationFrame = requestAnimationFrame(() => this.draw());

        if (!this.analyser) {
            this.drawIdleBars();
            return;
        }

        const bufferLength = this.analyser.frequencyBinCount;
        const dataArray = new Uint8Array(bufferLength);
        this.analyser.getByteFrequencyData(dataArray);

        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        // Calculate total width and starting position to center bars
        const totalWidth = (this.barWidth + this.barGap) * this.barCount - this.barGap;
        const startX = (this.canvas.width - totalWidth) / 2;
        const centerY = this.canvas.height / 2;
        const maxBarHeight = this.canvas.height * 0.7;

        // Sample the frequency data to get values for each bar
        const step = Math.floor(bufferLength / this.barCount);

        for (let i = 0; i < this.barCount; i++) {
            // Average a few frequency bins for smoother visualization
            let sum = 0;
            for (let j = 0; j < step; j++) {
                sum += dataArray[i * step + j] || 0;
            }
            const value = sum / step;

            // Calculate bar height with minimum
            const barHeight = Math.max(this.minBarHeight, (value / 255) * maxBarHeight);

            const x = startX + i * (this.barWidth + this.barGap);
            const y = centerY - barHeight / 2;

            // Draw rounded bar (pill shape)
            this.drawRoundedBar(x, y, this.barWidth, barHeight, this.barWidth / 2);
        }
    }

    drawRoundedBar(x, y, width, height, radius) {
        this.ctx.fillStyle = this.barColor;
        this.ctx.beginPath();

        // Draw pill shape using arcs
        const r = Math.min(radius, height / 2, width / 2);

        // Top semicircle
        this.ctx.arc(x + width / 2, y + r, r, Math.PI, 0);
        // Right side down
        this.ctx.lineTo(x + width / 2 + r, y + height - r);
        // Bottom semicircle
        this.ctx.arc(x + width / 2, y + height - r, r, 0, Math.PI);
        // Close path (left side up)
        this.ctx.closePath();
        this.ctx.fill();
    }

    drawIdleBars() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        const totalWidth = (this.barWidth + this.barGap) * this.barCount - this.barGap;
        const startX = (this.canvas.width - totalWidth) / 2;
        const centerY = this.canvas.height / 2;

        // Use semi-transparent blue for idle bars
        this.ctx.fillStyle = 'rgba(59, 130, 246, 0.5)';

        for (let i = 0; i < this.barCount; i++) {
            const x = startX + i * (this.barWidth + this.barGap);
            const barHeight = this.minBarHeight;
            const y = centerY - barHeight / 2;

            // Draw pill shape using arcs
            const radius = this.barWidth / 2;
            this.ctx.beginPath();
            // Top semicircle
            this.ctx.arc(x + radius, y + radius, radius, Math.PI, 0);
            // Right side down
            this.ctx.lineTo(x + this.barWidth, y + barHeight - radius);
            // Bottom semicircle
            this.ctx.arc(x + radius, y + barHeight - radius, radius, 0, Math.PI);
            // Left side up (closes path)
            this.ctx.closePath();
            this.ctx.fill();
        }
    }

    setAnalyser(analyser) {
        this.analyser = analyser;
    }
}

// Export for use in other modules
window.AudioCapture = AudioCapture;
window.AudioVisualizer = AudioVisualizer;
