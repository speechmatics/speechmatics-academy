export const MAX_AUDIO_BYTES = 100 * 1024 * 1024;

function checkAbort(signal) {
  if (signal?.aborted) throw new DOMException('Audio preparation was cancelled.', 'AbortError');
}

function byteLimit(value) {
  return Number.isFinite(value) && value > 0 ? Math.min(MAX_AUDIO_BYTES, Math.floor(value)) : MAX_AUDIO_BYTES;
}

// Pure PCM encoder. Interleave every original channel; do not downmix a channel-
// diarized recording. The rate here is the decoded AudioBuffer's sample rate.
export function encodePcm16Wav(audioBuffer, { maxBytes = MAX_AUDIO_BYTES } = {}) {
  const channels = audioBuffer?.numberOfChannels;
  const frames = audioBuffer?.length;
  const rate = audioBuffer?.sampleRate;
  if (!Number.isSafeInteger(channels) || channels < 1 || channels > 32767
    || !Number.isSafeInteger(frames) || frames < 1
    || !Number.isSafeInteger(rate) || rate < 1 || rate * channels * 2 > 0xffffffff
    || typeof audioBuffer.getChannelData !== 'function') throw new Error('The decoded audio has invalid channels, length, or sample rate.');
  const dataBytes = frames * channels * 2;
  const totalBytes = dataBytes + 44;
  if (!Number.isSafeInteger(totalBytes) || totalBytes > byteLimit(maxBytes)) throw new Error('The converted WAV is too large for the upload limit of 100 MiB. Use a shorter recording or a supported compressed audio file.');
  const data = Array.from({ length: channels }, (_, channel) => audioBuffer.getChannelData(channel));
  if (data.some(channel => !channel || channel.length !== frames)) throw new Error('The decoded audio channel lengths are invalid.');
  const result = new ArrayBuffer(totalBytes);
  const view = new DataView(result);
  const text = (offset, value) => { for (let i = 0; i < value.length; i++) view.setUint8(offset + i, value.charCodeAt(i)); };
  text(0, 'RIFF');
  view.setUint32(4, totalBytes - 8, true);
  text(8, 'WAVE'); text(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, channels, true);
  view.setUint32(24, rate, true);
  view.setUint32(28, rate * channels * 2, true);
  view.setUint16(32, channels * 2, true);
  view.setUint16(34, 16, true);
  text(36, 'data');
  view.setUint32(40, dataBytes, true);
  let offset = 44;
  for (let frame = 0; frame < frames; frame++) {
    for (let channel = 0; channel < channels; channel++) {
      const raw = data[channel][frame];
      const sample = Number.isFinite(raw) ? Math.min(1, Math.max(-1, raw)) : 0;
      view.setInt16(offset, Math.round(sample * (sample < 0 ? 32768 : 32767)), true);
      offset += 2;
    }
  }
  return result;
}

/** Convert browser WebM recordings locally because Batch does not accept WebM. */
export async function prepareAudioFile(file, {
  signal, AudioContextClass = globalThis.AudioContext || globalThis.webkitAudioContext,
  FileClass = globalThis.File, maxBytes = MAX_AUDIO_BYTES,
} = {}) {
  checkAbort(signal);
  if (!file || typeof file.name !== 'string' || !Number.isFinite(file.size) || file.size <= 0 || typeof file.arrayBuffer !== 'function') throw new Error('Choose a valid, non-empty audio file.');
  if (file.size > byteLimit(maxBytes)) throw new Error('The audio file is too large. Choose a file of 100 MiB or less.');
  const isWebM = /\.webm$/i.test(file.name) || /^(audio|video)\/webm(?:;|$)/i.test(file.type || '');
  if (!isWebM) return file;
  if (!AudioContextClass || !FileClass) throw new Error('This browser cannot convert WebM recordings. Upload a WAV, MP3, M4A, OGG, FLAC, AAC, or MP4 file instead.');
  let context;
  try {
    let decoded;
    try {
      const input = await file.arrayBuffer();
      checkAbort(signal);
      context = new AudioContextClass();
      decoded = await context.decodeAudioData(input);
    } catch (error) {
      checkAbort(signal);
      if (error?.name === 'AbortError') throw error;
      throw new Error('This browser could not decode the WebM recording. Convert it to WAV or MP3, or upload another supported audio file.');
    }
    checkAbort(signal);
    const wav = encodePcm16Wav(decoded, { maxBytes });
    checkAbort(signal);
    const basename = file.name.replace(/\.webm$/i, '') || 'consultation';
    return new FileClass([wav], `${basename}.wav`, { type: 'audio/wav', lastModified: file.lastModified ?? Date.now() });
  } finally {
    try { await context?.close(); } catch { /* Conversion outcome takes precedence over decoder shutdown errors. */ }
  }
}
