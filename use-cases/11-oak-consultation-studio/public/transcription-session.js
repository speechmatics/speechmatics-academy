import { DEFAULT_BATCH_REGION } from './batch-endpoints.js';

const ACTIVE = new Set(['preparing', 'authorizing', 'uploading', 'running', 'cancelling']);

export function createTranscriptionSession({ createClient, prepareAudio, normalize, onChange = () => {} }) {
  let state = { status: 'ready', message: '', canResume: false };
  let version = 0;
  let controller;
  let client;
  let metadata;
  let operation;
  const change = update => { state = { ...state, ...update }; onChange({ ...state }); };

  async function poll(current, active) {
    try {
      const result = await active.client.waitForTranscript(active.jobId, {
        signal: active.controller.signal,
        onStatus: () => { if (current === version) change({ status: 'running', message: 'Oak 1 is transcribing your conversation…' }); },
      });
      if (current !== version) return;
      const sample = normalize(result, { ...active.metadata, jobId: active.jobId });
      change({ status: 'done', sample, canResume: false, message: 'Transcription complete.' });
      active.client.clearCredentials();
    } catch (error) {
      if (current !== version) return;
      change({ status: 'error', message: error.message || 'Unable to retrieve this transcription.', canResume: !['JOB_FAILED', 'JOB_REJECTED', 'JOB_MISSING'].includes(error.code) });
    }
  }

  return {
    get state() { return { ...state }; },
    get busy() { return ACTIVE.has(state.status); },
    async start(file, options = {}) {
      if (ACTIVE.has(state.status)) return;
      const current = ++version;
      controller = new AbortController();
      client?.clearCredentials();
      client = createClient({ apiKey: options.apiKey || '', region: options.region || DEFAULT_BATCH_REGION });
      metadata = { ...options.metadata, region: options.region || DEFAULT_BATCH_REGION };
      const active = operation = { client, controller, metadata, cancelRequested: false };
      state = { status: 'preparing', message: 'Preparing your audio…', canResume: false };
      change({});
      try {
        const audio = await prepareAudio(file, { signal: active.controller.signal });
        if (current !== version) return;
        const jobId = await active.client.submit(audio, options.config, {
          signal: active.controller.signal,
          onProgress: progress => {
            if (current !== version) return;
            const phase = progress.phase;
            change({ status: phase === 'submitted' ? 'running' : phase, message: phase === 'authorizing' ? 'Connecting to Speechmatics…' : phase === 'uploading' ? 'Uploading audio to Speechmatics…' : 'Oak 1 is transcribing your conversation…' });
          },
        });
        active.jobId = jobId;
        if (current !== version) {
          if (active.cancelRequested) {
            // Only explicit cancellation deletes a late job, using its own client.
            try { await active.client.cancel(jobId); } catch { /* The cancelled state already explains the uncertain upload. */ }
          } else if (operation === active && state.status === 'error') {
            // A page pause can learn the job ID later, without deleting remotely.
            change({ jobId, canResume: true, message: 'Stopped waiting for this job. Reconnect to retrieve its result.' });
          }
          return;
        }
        change({ jobId, status: 'running', message: 'Oak 1 is transcribing your conversation…' });
        await poll(current, active);
      } catch (error) {
        if (current !== version) return;
        change({ status: 'error', canResume: false, message: error.message || 'Unable to submit this audio.' });
        active.client.clearCredentials();
      }
    },
    async resume(options = {}) {
      if (ACTIVE.has(state.status) || !state.canResume || !state.jobId) return;
      if (Object.hasOwn(options, 'apiKey')) {
        const replacement = createClient({ apiKey: options.apiKey || '', region: metadata.region });
        client?.clearCredentials();
        client = replacement;
      }
      controller = new AbortController();
      const current = ++version;
      const active = operation = { client, controller, metadata, jobId: state.jobId, cancelRequested: false };
      change({ status: 'running', message: 'Reconnecting to your transcription…', canResume: false });
      await poll(current, active);
    },
    async cancel() {
      if (state.status === 'cancelling') return;
      const previousStatus = state.status;
      const jobId = state.jobId;
      const active = operation;
      if (active) active.cancelRequested = true;
      const current = ++version;
      controller?.abort();
      change({ status: 'cancelling', message: 'Cancelling transcription…', canResume: false });
      try {
        if (jobId) await active.client.cancel(jobId);
        else active?.client.clearCredentials();
        if (current !== version) return;
        change({ status: 'cancelled', message: previousStatus === 'uploading'
          ? 'Upload stopped. If Speechmatics already accepted it, the job may still run. Check your Speechmatics Portal before trying again.'
          : 'Transcription cancelled. Your audio is still available to play.', canResume: false });
      } catch {
        if (current !== version) return;
        change({ status: 'error', message: 'Cancellation could not be confirmed. The job may still be running; reconnect to retrieve its result.', canResume: Boolean(jobId) });
      }
    },
    reset() {
      if (ACTIVE.has(state.status)) return false;
      ++version;
      client?.clearCredentials();
      client = null;
      operation = null;
      state = { status: 'ready', message: '', canResume: false };
      change({});
      return true;
    },
    abandon() {
      if (ACTIVE.has(state.status)) return false;
      ++version;
      controller?.abort();
      client?.clearCredentials();
      client = operation = null;
      state = { status: 'cancelled', canResume: false, message: 'Stopped tracking this job. It was not cancelled and may still run. Check your Speechmatics Portal before submitting this audio again.' };
      change({});
      return true;
    },
    stopWaiting() {
      const previousStatus = state.status;
      const wasWaiting = ACTIVE.has(previousStatus) || state.canResume;
      ++version;
      controller?.abort();
      if (!wasWaiting) { client?.clearCredentials(); return; }
      // A cached page may resume or cancel this job later. Keep its original
      // in-memory credentials so cancellation cannot switch to a server key.
      change({ status: 'error', canResume: Boolean(state.jobId), message: state.jobId
        ? 'Stopped waiting for this job. Reconnect to retrieve its result.'
        : previousStatus === 'uploading'
          ? 'Upload tracking stopped. The job may still run. Check your Speechmatics Portal before submitting this audio again.'
          : 'Audio preparation stopped. You can start again when ready.' });
    },
  };
}
