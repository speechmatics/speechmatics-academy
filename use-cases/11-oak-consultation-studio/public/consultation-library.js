import { createRequestConfig } from './transcript.js';
import { DEFAULT_BATCH_REGION } from './batch-endpoints.js';

// Every local consultation owns its audio and job session for this page's lifetime.
export function createConsultationLibrary({
  createSession, onChange = () => {},
  createId = () => globalThis.crypto.randomUUID(), now = () => new Date(),
}) {
  if (typeof createSession !== 'function') throw new TypeError('A transcription session factory is required.');
  const consultations = new Map();
  const pending = new Map();
  let disposed = false;
  let duplicateId = 0;

  function requireEntry(id) {
    const entry = consultations.get(id);
    if (!entry) throw new Error('This consultation is no longer available.');
    return entry;
  }

  function update(entry, progress) {
    if (progress.status === 'done' && progress.sample) {
      const { id, title } = entry.sample;
      // Selection and playback hold this object. Keep it stable when results arrive.
      Object.assign(entry.sample, progress.sample, { id, title });
    }
    onChange(entry, progress);
  }

  async function transcribe(id, options = {}) {
    if (disposed) throw new Error('This consultation library has been released.');
    const entry = requireEntry(id);
    if (pending.has(id)) return pending.get(id);
    const { sample, session } = entry;
    if (session.busy || sample.transcribed || session.state?.status === 'done') return;
    const task = session.state?.canResume
      ? session.resume(Object.hasOwn(options, 'apiKey') ? { apiKey: options.apiKey } : undefined)
      : session.start(entry.file, {
        apiKey: options.apiKey || '', region: sample.region,
        config: createRequestConfig(sample),
        metadata: {
          title: sample.title, duration: sample.duration, region: sample.region,
          locale: sample.locale, diarization: sample.diarization,
        },
      });
    const promise = Promise.resolve(task);
    pending.set(id, promise);
    try { return await promise; }
    finally { if (pending.get(id) === promise) pending.delete(id); }
  }

  function add(file, media, { source = 'upload', apiKey = '' } = {}) {
    if (disposed) throw new Error('This consultation library has been released.');
    if (!file || typeof file.name !== 'string' || !media || !Number.isFinite(media.duration) || media.duration <= 0) {
      throw new Error('A valid audio file and its playable media are required.');
    }
    if (!['upload', 'recording'].includes(source)) throw new Error('Choose an upload or recording source.');
    const baseId = `local-${createId()}`;
    let id = baseId;
    while (consultations.has(id)) id = `${baseId}-${++duplicateId}`;
    const timestamp = source === 'recording' ? now() : null;
    const sample = {
      id,
      title: source === 'recording' ? `Consultation · ${timestamp.toLocaleString(undefined, {
        year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
      })}` : file.name,
      description: 'Your recording, ready for multilingual transcription with Oak 1.',
      duration: media.duration, languages: [], speakerNames: {},
      specialty: 'Local audio · ready to transcribe', region: DEFAULT_BATCH_REGION, locale: 'en-GB',
      diarization: 'speaker', isDemo: false, utterances: [],
    };
    let entry;
    const initialProgress = [];
    const session = createSession({ onChange: progress => {
      if (!entry) { initialProgress.push(progress); return; }
      update(entry, progress);
    } });
    entry = { sample, file, media, session, source };
    consultations.set(id, entry);
    onChange(entry, { status: 'ready', canResume: false, message: '' });
    initialProgress.forEach(progress => update(entry, progress));
    // Both uploads and recordings start after the caller selects/configures the
    // registered entry, so progress always belongs to the right consultation.
    void Promise.resolve().then(() => {
      if (!disposed) return transcribe(id, { apiKey });
    }).catch(error => {
      if (!disposed) onChange(entry, { status: 'error', canResume: false, message: error.message || 'Unable to start this transcription.' });
    });
    return entry;
  }

  function rename(id, title) {
    const entry = requireEntry(id);
    if (typeof title !== 'string' || !title.trim()) throw new Error('Enter a consultation title.');
    const value = Array.from(title.trim()).slice(0, 120).join('');
    entry.sample.title = value;
    onChange(entry, { status: 'renamed', title: value });
    return value;
  }

  function stopWaiting() {
    for (const entry of consultations.values()) entry.session.stopWaiting?.();
  }

  function releaseAll() {
    if (disposed) return;
    disposed = true;
    for (const entry of consultations.values()) {
      try { entry.session.stopWaiting?.(); } catch { /* Continue releasing all media. */ }
      try { entry.media.release?.(); } catch { /* One failed cleanup cannot retain other media URLs. */ }
    }
  }

  return { entries: () => [...consultations.values()], get: id => consultations.get(id), add, transcribe, rename, stopWaiting, releaseAll };
}
