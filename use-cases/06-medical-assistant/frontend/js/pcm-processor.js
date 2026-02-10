/**
 * PCM Audio Worklet Processor
 * Runs on the audio rendering thread - converts float32 audio to 16-bit PCM
 * and sends it to the main thread via MessagePort.
 */
class PCMProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.bufferSize = 4096;
        this.buffer = new Float32Array(this.bufferSize);
        this.bufferIndex = 0;
    }

    process(inputs) {
        const input = inputs[0];
        if (!input || !input[0]) return true;

        const channelData = input[0];

        for (let i = 0; i < channelData.length; i++) {
            this.buffer[this.bufferIndex++] = channelData[i];

            if (this.bufferIndex >= this.bufferSize) {
                // Convert accumulated buffer to 16-bit PCM
                const int16 = new Int16Array(this.bufferSize);
                for (let j = 0; j < this.bufferSize; j++) {
                    const s = Math.max(-1, Math.min(1, this.buffer[j]));
                    int16[j] = s < 0 ? s * 0x8000 : s * 0x7FFF;
                }

                this.port.postMessage(int16.buffer, [int16.buffer]);
                this.buffer = new Float32Array(this.bufferSize);
                this.bufferIndex = 0;
            }
        }

        return true;
    }
}

registerProcessor('pcm-processor', PCMProcessor);
