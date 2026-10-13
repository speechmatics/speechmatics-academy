export const WAVEFORM_BARS = 130;

/** Measure each time bin across every channel without cancelling opposite phases. */
export function getAudioPeaks(audioBuffer, { barCount = WAVEFORM_BARS } = {}) {
  if (!Number.isSafeInteger(barCount) || barCount < 1) throw new RangeError('Waveform bar count must be a positive integer.');
  const peaks = new Float32Array(barCount);
  const frames = audioBuffer?.length;
  const channelCount = audioBuffer?.numberOfChannels;
  if (!Number.isSafeInteger(frames) || frames < 1
    || !Number.isSafeInteger(channelCount) || channelCount < 1
    || typeof audioBuffer.getChannelData !== 'function') return peaks;

  let channels;
  try {
    channels = Array.from({ length: channelCount }, (_, channel) => audioBuffer.getChannelData(channel));
    if (channels.some(channel => !channel || channel.length !== frames)) return peaks;
  } catch { return peaks; }

  let maximum = 0;
  for (let bar = 0; bar < barCount; bar++) {
    const start = Math.floor(bar * frames / barCount);
    // Repeat the nearest available sample when a clip has fewer frames than bars.
    const end = Math.max(start + 1, Math.floor((bar + 1) * frames / barCount));
    let peak = 0;
    for (const channel of channels) {
      for (let frame = start; frame < end; frame++) {
        const sample = channel[frame];
        if (Number.isFinite(sample)) peak = Math.max(peak, Math.abs(sample));
      }
    }
    peaks[bar] = peak;
    maximum = Math.max(maximum, peak);
  }
  // Normalize quiet recordings, leaving actual silence at zero.
  if (maximum > 0) {
    for (let bar = 0; bar < barCount; bar++) peaks[bar] /= maximum;
  }
  return peaks;
}

function abortError() {
  return new DOMException('Audio waveform preparation was cancelled.', 'AbortError');
}

function checkAbort(signal) {
  if (signal?.aborted) throw abortError();
}

function abortable(operation, signal) {
  if (!signal) return operation;
  return new Promise((resolve, reject) => {
    const cleanup = () => signal.removeEventListener('abort', onAbort);
    const onAbort = () => { cleanup(); reject(abortError()); };
    signal.addEventListener('abort', onAbort, { once: true });
    Promise.resolve(operation).then(
      value => { cleanup(); resolve(value); },
      error => { cleanup(); reject(error); },
    );
    if (signal.aborted) onAbort();
  });
}

/** Decode only for a local preview; the original upload remains untouched. */
export async function createAudioWaveform(file, {
  signal, AudioContextClass = globalThis.AudioContext || globalThis.webkitAudioContext,
  barCount = WAVEFORM_BARS,
} = {}) {
  checkAbort(signal);
  if (!file || typeof file.arrayBuffer !== 'function') throw new Error('Choose a valid audio file to create its waveform.');
  if (!AudioContextClass) throw new Error('This browser cannot create an audio waveform preview.');
  let context;
  try {
    const input = await abortable(file.arrayBuffer(), signal);
    checkAbort(signal);
    // A speech preview needs far less PCM memory than playback-quality decoding.
    try { context = new AudioContextClass({ sampleRate: 8000 }); }
    catch { context = new AudioContextClass(); }
    const decoded = await abortable(context.decodeAudioData(input), signal);
    checkAbort(signal);
    return getAudioPeaks(decoded, { barCount });
  } catch (error) {
    if (signal?.aborted || error?.name === 'AbortError') throw abortError();
    throw new Error('This browser could not decode an audio waveform preview.');
  } finally {
    try { await context?.close(); } catch { /* The preview result takes precedence over shutdown errors. */ }
  }
}
