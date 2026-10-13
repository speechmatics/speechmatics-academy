// Audio goes directly to Speechmatics. Only temporary-token creation uses Python.
// Credentials live inside this closure; never persist them in browser storage.
import { BATCH_ENDPOINTS as ENDPOINTS, DEFAULT_BATCH_REGION } from './batch-endpoints.js';
const MAX_WAIT_MS = 2 * 60 * 60 * 1000;
const MAX_BACKOFF_MS = 15000;
const RETRYABLE = new Set(['NETWORK', 'REQUEST_TIMEOUT', 'RATE_LIMITED', 'SERVICE_UNAVAILABLE']);
let brokerQueue = Promise.resolve();

// Finish receiving the broker's scope cookie before another client authorizes.
// Web Locks extend the same ordering across tabs; the promise queue is the fallback.
async function withBrokerTurn(task, signal) {
  checkAbort(signal);
  const preceding = brokerQueue;
  let release;
  const turn = new Promise(resolve => { release = resolve; });
  brokerQueue = preceding.then(() => turn);
  let onAbort;
  try {
    const cancelled = new Promise((resolve, reject) => {
      onAbort = () => reject(new DOMException('The operation was cancelled.', 'AbortError'));
      signal?.addEventListener('abort', onAbort, { once: true });
    });
    await Promise.race([preceding, cancelled]);
    checkAbort(signal);
    const locks = globalThis.navigator?.locks;
    if (locks?.request) {
      return await locks.request('speechmatics.oak.token-broker', { mode: 'exclusive', ...(signal ? { signal } : {}) }, () => {
        checkAbort(signal);
        return task();
      });
    }
    return await task();
  } finally {
    signal?.removeEventListener('abort', onAbort);
    release();
  }
}

export class BatchClientError extends Error {
  constructor(code, message, { status, retryAfterMs } = {}) {
    super(message);
    this.name = 'BatchClientError';
    this.code = code;
    if (status != null) this.status = status;
    if (retryAfterMs != null) this.retryAfterMs = retryAfterMs;
  }
}

function checkAbort(signal) {
  if (signal?.aborted) throw new DOMException('The operation was cancelled.', 'AbortError');
}

export function abortableSleep(milliseconds, signal) {
  checkAbort(signal);
  return new Promise((resolve, reject) => {
    const abort = () => {
      globalThis.clearTimeout(timer);
      signal?.removeEventListener('abort', abort);
      reject(new DOMException('The operation was cancelled.', 'AbortError'));
    };
    const timer = globalThis.setTimeout(() => { signal?.removeEventListener('abort', abort); resolve(); }, milliseconds);
    signal?.addEventListener('abort', abort, { once: true });
  });
}

function jobPath(jobId) {
  if (typeof jobId !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(jobId)) {
    throw new BatchClientError('INVALID_JOB_ID', 'Speechmatics returned an invalid job identifier.');
  }
  return `/jobs/${jobId}`;
}

function retryDelay(response, now) {
  const value = response.headers?.get('Retry-After');
  if (!value) return undefined;
  const seconds = Number(value);
  const milliseconds = Number.isFinite(seconds) ? seconds * 1000 : Date.parse(value) - now();
  return Number.isFinite(milliseconds) ? Math.min(MAX_BACKOFF_MS, Math.max(1000, milliseconds)) : undefined;
}

function responseError(response, { broker = false, uploading = false, now } = {}) {
  const { status } = response;
  if (broker && status === 400) return new BatchClientError('INVALID_KEY', 'Add or check your Speechmatics API key in Settings.', { status });
  if (status === 401) return new BatchClientError('UNAUTHORIZED', broker
    ? 'The Speechmatics API key was not accepted. Check the key and try again.'
    : uploading ? 'The upload was not authorised and was not retried. Check your key and try again.'
      : 'Speechmatics authorisation expired or was rejected. Check your API key and try again.', { status });
  if (status === 403) return new BatchClientError('ACCESS_DENIED', 'Speechmatics access was denied. Confirm this key has Oak 1 Batch access.', { status });
  if (status === 429) return new BatchClientError('RATE_LIMITED', 'Speechmatics is busy or the request limit has been reached. Please try again later.', { status, retryAfterMs: retryDelay(response, now) });
  if (status === 404) return new BatchClientError(broker ? 'TOKEN_ENDPOINT_MISSING' : 'JOB_MISSING', broker
    ? 'The Python token endpoint is unavailable. Run the app with its Python backend.'
    : 'This Speechmatics job is no longer available. It may have been deleted.', { status });
  if (status === 413) return new BatchClientError('FILE_TOO_LARGE', 'The audio file is too large. Choose a file of 100 MiB or less.', { status });
  if (status >= 500 && uploading) return new BatchClientError('UPLOAD_UNCERTAIN', 'The upload response failed, but Speechmatics may have accepted the audio. Check your Speechmatics Portal before submitting again; the upload was not retried.', { status });
  if (status >= 500) return new BatchClientError('SERVICE_UNAVAILABLE', broker
    ? 'The token service is unavailable. Check that a Speechmatics API key is configured and try again.'
    : 'Speechmatics is temporarily unavailable. The job may still be processing; try again shortly.', { status, retryAfterMs: retryDelay(response, now) });
  return new BatchClientError('REQUEST_REJECTED', uploading
    ? 'Speechmatics could not accept the audio or configuration. Check the file format and Oak 1 settings.'
    : 'Speechmatics could not complete this request. Check your access and try again.', { status });
}

async function readJson(response) {
  try { return await response.json(); }
  catch { throw new BatchClientError('INVALID_RESPONSE', 'Speechmatics returned an unreadable response. Please try again.'); }
}

/**
 * onProgress receives {phase: 'authorizing'|'uploading'|'submitted', jobId?}.
 * onStatus receives a documented job status string. Aborting only stops local
 * polling; call cancel(jobId) separately when the user requests remote deletion.
 */
export function createBatchClient({
  apiKey = '', region = DEFAULT_BATCH_REGION, fetcher = (...args) => globalThis.fetch(...args),
  sleep = abortableSleep, now = () => Date.now(), pollIntervalMs = 1500,
  maxWaitMs = MAX_WAIT_MS, requestTimeoutMs = 60000, uploadTimeoutMs = 5 * 60 * 1000,
  FormDataClass = globalThis.FormData,
} = {}) {
  if (!Object.hasOwn(ENDPOINTS, region)) throw new BatchClientError('INVALID_REGION', 'Choose the EU1 or US1 Speechmatics endpoint for Oak 1.');
  if (typeof apiKey !== 'string' || apiKey.length > 8192 || /[\r\n]/.test(apiKey)) throw new BatchClientError('INVALID_KEY', 'Enter a valid Speechmatics API key.');
  if (typeof fetcher !== 'function' || typeof sleep !== 'function' || typeof now !== 'function') throw new TypeError('A fetcher, sleep, and clock are required.');
  const endpoint = ENDPOINTS[region];
  const waitLimit = Math.min(MAX_WAIT_MS, Math.max(1, Number(maxWaitMs) || MAX_WAIT_MS));
  const pollDelay = Math.min(MAX_BACKOFF_MS, Math.max(250, Number(pollIntervalMs) || 1500));
  let key = apiKey.trim();
  let token = '';
  let expiresAt = 0;
  let credentialVersion = 0;

  function clearCredentials() {
    key = token = '';
    expiresAt = 0;
    credentialVersion++;
  }

  // A per-request deadline also bounds a stalled connection during polling.
  async function send(url, options, { signal, timeoutMs = requestTimeoutMs, uploading = false, parseJson = true } = {}) {
    checkAbort(signal);
    const controller = new AbortController();
    let timedOut = false;
    let interrupt;
    const interrupted = new Promise((resolve, reject) => { interrupt = reject; });
    const abort = () => { controller.abort(); interrupt(new DOMException('The operation was cancelled.', 'AbortError')); };
    const timer = globalThis.setTimeout(() => {
      timedOut = true;
      controller.abort();
      interrupt(new BatchClientError('REQUEST_TIMEOUT', 'The Speechmatics request timed out. Try again shortly.'));
    }, Math.max(1, timeoutMs));
    signal?.addEventListener('abort', abort, { once: true });
    try {
      const result = await Promise.race([interrupted, (async () => {
        const response = await fetcher(url, { ...options, signal: controller.signal, redirect: 'error', cache: 'no-store' });
        const data = response.ok && parseJson ? await readJson(response) : undefined;
        return { response, data };
      })()]);
      checkAbort(signal);
      return result;
    } catch (error) {
      checkAbort(signal);
      if (uploading) throw new BatchClientError('UPLOAD_UNCERTAIN', 'The upload connection was interrupted. Check your Speechmatics jobs before submitting again; the upload was not retried.');
      if (error instanceof BatchClientError) throw error;
      if (timedOut) throw new BatchClientError('REQUEST_TIMEOUT', 'The Speechmatics request timed out. Try again shortly.');
      throw new BatchClientError('NETWORK', 'Could not reach Speechmatics. Check your connection and try again.');
    } finally {
      globalThis.clearTimeout(timer);
      signal?.removeEventListener('abort', abort);
    }
  }

  async function authorize(signal, timeoutMs = requestTimeoutMs) {
    checkAbort(signal);
    if (token && expiresAt - now() > 30000) return token;
    const version = credentialVersion;
    const headers = { 'Content-Type': 'application/json' };
    if (key) headers.Authorization = `Bearer ${key}`;
    const { response, data } = await withBrokerTurn(() => {
      checkAbort(signal);
      if (version !== credentialVersion) throw new DOMException('The operation was cancelled.', 'AbortError');
      return send('./api/token', { method: 'POST', headers, body: '{}', credentials: 'same-origin' }, { signal, timeoutMs });
    }, signal);
    if (!response.ok) throw responseError(response, { broker: true, now });
    checkAbort(signal);
    if (typeof data?.token !== 'string' || data.token.length < 1 || data.token.length > 16384 || /\s/.test(data.token)
      || !Number.isFinite(data.expires_in) || data.expires_in <= 0) {
      throw new BatchClientError('INVALID_RESPONSE', 'The Python backend returned an invalid temporary token. Please try again.');
    }
    if (version !== credentialVersion) throw new DOMException('The operation was cancelled.', 'AbortError');
    token = data.token;
    expiresAt = now() + Math.min(600, data.expires_in) * 1000;
    return token;
  }

  async function request(path, { method = 'GET', body, signal, timeoutMs, uploading = false } = {}) {
    const deadline = now() + (timeoutMs ?? requestTimeoutMs);
    const remaining = () => {
      checkAbort(signal);
      const left = deadline - now();
      if (left <= 0) throw new BatchClientError('REQUEST_TIMEOUT', 'The Speechmatics request timed out. Try again shortly.');
      return left;
    };
    for (let attempt = 0; attempt < 2; attempt++) {
      const bearer = await authorize(signal, remaining());
      const { response, data } = await send(`${endpoint}${path}`, {
        method, headers: { Authorization: `Bearer ${bearer}` }, credentials: 'omit', ...(body ? { body } : {}),
      }, { signal, timeoutMs: remaining(), uploading, parseJson: method !== 'DELETE' });
      if (response.status === 401 && method === 'GET' && attempt === 0) { token = ''; expiresAt = 0; continue; }
      if (!response.ok) throw responseError(response, { uploading, now });
      return data;
    }
  }

  async function submit(file, config, { signal, onProgress } = {}) {
    checkAbort(signal);
    if (!file || !Number.isFinite(file.size) || file.size <= 0 || file.size > 100 * 1024 * 1024) throw new BatchClientError('INVALID_FILE', 'Choose an audio file between 1 byte and 100 MiB.');
    let configJson;
    try {
      if (!config || typeof config !== 'object' || Array.isArray(config)) throw new Error();
      configJson = JSON.stringify(config);
    } catch { throw new BatchClientError('INVALID_CONFIG', 'The transcription configuration is invalid.'); }
    onProgress?.({ phase: 'authorizing' });
    await authorize(signal);
    checkAbort(signal);
    const body = new FormDataClass();
    body.append('data_file', file, file.name || 'consultation.wav');
    body.append('config', configJson);
    onProgress?.({ phase: 'uploading' });
    // Uploading has no automatic retries: a lost response may still create a job.
    const data = await request('/jobs', { method: 'POST', body, signal, timeoutMs: uploadTimeoutMs, uploading: true });
    checkAbort(signal);
    try { jobPath(data?.id); }
    catch { throw new BatchClientError('UPLOAD_UNCERTAIN', 'The upload response did not include a valid job identifier. Check your Speechmatics jobs before submitting again; the upload was not retried.'); }
    onProgress?.({ phase: 'submitted', jobId: data.id });
    return data.id;
  }

  async function waitForTranscript(jobId, { signal, onStatus } = {}) {
    const path = jobPath(jobId);
    const deadline = now() + waitLimit;
    const remaining = () => {
      checkAbort(signal);
      const left = deadline - now();
      if (left <= 0) throw new BatchClientError('POLL_TIMEOUT', 'The polling time limit was reached. The job may still be processing; resume checking or cancel it.');
      return left;
    };
    const pause = async milliseconds => { await sleep(Math.min(milliseconds, remaining()), signal); remaining(); };
    async function read(pathname) {
      let attempts = 0;
      for (;;) {
        try {
          return await request(pathname, { signal, timeoutMs: Math.min(requestTimeoutMs, remaining()) });
        } catch (error) {
          checkAbort(signal);
          if (!RETRYABLE.has(error?.code)) throw error;
          const backoff = Math.min(MAX_BACKOFF_MS, pollDelay * 2 ** Math.min(attempts++, 4));
          await pause(error.retryAfterMs ?? backoff);
        }
      }
    }
    for (;;) {
      const data = await read(`${path}?wait=0`);
      const status = data?.job?.status;
      if (!['created', 'queued', 'running', 'done', 'rejected', 'failed', 'deleted'].includes(status)) throw new BatchClientError('INVALID_RESPONSE', 'Speechmatics returned an unknown job status. Please try checking the job again.');
      onStatus?.(status);
      if (status === 'rejected') throw new BatchClientError('JOB_REJECTED', 'Speechmatics rejected this job. Check the audio format, configuration, and Oak 1 access.');
      if (status === 'failed') throw new BatchClientError('JOB_FAILED', 'Speechmatics could not transcribe this job. Check the audio file and try again.');
      if (status === 'deleted') throw new BatchClientError('JOB_MISSING', 'This Speechmatics job has been deleted.');
      if (status === 'done') {
        const transcript = await read(`${path}/transcript?format=json-v2&wait=0`);
        if (!transcript || !Array.isArray(transcript.results)) throw new BatchClientError('INVALID_RESPONSE', 'Speechmatics returned an invalid transcript. Please try retrieving this job again.');
        return transcript;
      }
      await pause(pollDelay);
    }
  }

  async function cancel(jobId) {
    const path = jobPath(jobId);
    // Deliberately independent of any aborted upload/polling signal.
    try { await request(path, { method: 'DELETE' }); }
    catch (error) { if (error.status !== 404 || error.code !== 'JOB_MISSING') throw error; }
    clearCredentials();
  }

  return { submit, waitForTranscript, cancel, clearCredentials };
}
