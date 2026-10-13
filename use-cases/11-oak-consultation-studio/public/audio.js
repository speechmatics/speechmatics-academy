const MAX_FILE_BYTES = 100 * 1024 * 1024;
const MAX_RECORDING_MS = 5 * 60 * 1000;

export function seekAudio(audio, time, duration) {
  if (!audio || !Number.isFinite(time) || !Number.isFinite(duration) || duration <= 0) return false;
  try {
    audio.currentTime = Math.min(duration, Math.max(0, time));
    return true;
  } catch { return false; }
}

export function validateAudioFile(file) {
  if (!file || typeof file.name !== 'string' || !Number.isFinite(file.size) || file.size < 0) return 'Choose a valid audio file.';
  if (file.size === 0) return 'This file is empty. Choose a file containing audio.';
  if (file.size > MAX_FILE_BYTES) return 'Choose an audio file of 100 MiB or less.';
  if (!/\.(wav|mp3|m4a|ogg|flac|aac|mp4|webm)$/i.test(file.name)) return 'Supported formats: WAV, MP3, M4A, OGG, FLAC, AAC, MP4, and WebM.';
  return null;
}

// Call start() from a user gesture. Dependencies can be injected for lifecycle tests.
export function createRecorder({ onTick, onStopped, onError } = {}, dependencies = {}) {
  const browser = {
    mediaDevices: globalThis.navigator?.mediaDevices,
    MediaRecorder: globalThis.MediaRecorder,
    File: globalThis.File,
    now: () => Date.now(),
    setInterval: (...args) => globalThis.setInterval(...args),
    clearInterval: (...args) => globalThis.clearInterval(...args),
    setTimeout: (...args) => globalThis.setTimeout(...args),
    clearTimeout: (...args) => globalThis.clearTimeout(...args),
    ...dependencies,
  };
  let session;
  const asError = error => error instanceof Error ? error : new Error(error?.message || 'Recording failed. Please try again.');
  const elapsed = current => Number.isFinite(current?.startedAt)
    ? Math.min(MAX_RECORDING_MS, Math.max(0, browser.now() - current.startedAt)) / 1000 : 0;

  function cleanup(current) {
    current.duration ??= elapsed(current);
    if (current.interval != null) browser.clearInterval(current.interval);
    if (current.timeout != null) browser.clearTimeout(current.timeout);
    current.interval = current.timeout = null;
    if (current.stream && !current.released) {
      current.released = true;
      current.stream.getTracks().forEach(track => track.stop());
    }
  }

  function halt(current) {
    if (current.recorder && current.recorder.state !== 'inactive' && !current.stopping) {
      current.stopping = true;
      current.recorder.stop();
    }
  }

  function fail(current, error) {
    if (current.settled || current.cancelled) return;
    current.settled = current.cancelled = true;
    current.active = false;
    current.chunks = [];
    cleanup(current);
    try { halt(current); } catch { /* Resources are already released. */ }
    onError?.(asError(error));
  }

  function cancel() {
    if (!session || session.cancelled || session.settled) return;
    session.cancelled = true;
    session.active = false;
    session.chunks = [];
    cleanup(session);
    try { halt(session); } catch { /* Cancellation still releases the microphone. */ }
  }

  function stop() {
    if (!session || session.settled || session.cancelled || session.stopping) return;
    if (!session.recorder) { cancel(); return; }
    session.active = false;
    try { halt(session); } catch (error) { fail(session, error); }
    cleanup(session);
  }

  function start() {
    if (session && !session.settled && !session.cancelled) return session.promise;
    const current = { active: false, cancelled: false, settled: false, stopping: false, chunks: [] };
    session = current;
    current.promise = (async () => {
      try {
        if (!browser.mediaDevices?.getUserMedia || !browser.MediaRecorder) throw new Error('Microphone recording is unavailable in this browser. Use an audio file instead.');
        current.stream = await browser.mediaDevices.getUserMedia({ audio: true });
        if (current.cancelled) { cleanup(current); return false; }
        const mimeType = ['audio/webm', 'audio/mp4', 'audio/ogg'].find(type => browser.MediaRecorder.isTypeSupported?.(type));
        const native = new browser.MediaRecorder(current.stream, mimeType ? { mimeType } : undefined);
        current.recorder = native;
        native.ondataavailable = event => {
          if (!current.cancelled && !current.settled && event.data?.size > 0) current.chunks.push(event.data);
        };
        native.onerror = event => fail(current, event.error);
        native.onstop = () => {
          if (current.settled || current.cancelled) return;
          current.active = false;
          cleanup(current);
          try {
            const type = native.mimeType || current.chunks[0]?.type || mimeType || 'audio/webm';
            const extension = type.includes('mp4') ? 'm4a' : type.includes('ogg') ? 'ogg' : type.includes('wav') ? 'wav' : 'webm';
            const file = new browser.File(current.chunks, `consultation-recording.${extension}`, { type });
            current.chunks = [];
            current.settled = true;
            onStopped?.(file);
          } catch (error) { fail(current, error); }
        };
        native.start();
        current.startedAt = browser.now();
        current.active = true;
        onTick?.(0);
        current.interval = browser.setInterval(() => {
          if (current.active) onTick?.(elapsed(current));
        }, 250);
        current.timeout = browser.setTimeout(() => { if (session === current) stop(); }, MAX_RECORDING_MS);
      } catch (error) {
        current.active = false;
        current.settled = true;
        cleanup(current);
        try { halt(current); } catch { /* Preserve the startup error. */ }
        if (current.cancelled) return false;
        current.cancelled = true;
        throw asError(error);
      }
    })();
    return current.promise;
  }

  return {
    start, stop, cancel,
    get active() { return Boolean(session?.active); },
    get recordedDuration() { return session?.duration ?? elapsed(session); },
  };
}
