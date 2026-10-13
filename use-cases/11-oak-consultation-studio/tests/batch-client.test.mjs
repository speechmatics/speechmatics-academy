import test from 'node:test';
import assert from 'node:assert/strict';
import { createBatchClient } from '../public/batch-client.js';

const response = (body, status = 200, headers = {}) => new Response(JSON.stringify(body), { status, headers });
const token = (value = 'temporary-token', expires_in = 600) => response({ token: value, expires_in });
const audioFile = () => new File(['audio'], 'consultation.wav', { type: 'audio/wav' });

function transport(responses) {
  const calls = [];
  const fetcher = async (url, options) => {
    calls.push({ url, ...options });
    assert.ok(responses.length, `Unexpected request: ${url}`);
    const next = responses.shift();
    if (next instanceof Error) throw next;
    return typeof next === 'function' ? next(url, options) : next;
  };
  return { calls, fetcher };
}

test('cold clients serialize broker calls with their own keys while audio uploads remain concurrent', async () => {
  let finishFirstToken;
  let finishFirstUpload;
  const calls = [];
  const fetcher = async (url, options) => {
    calls.push({ url, authorization: options.headers.Authorization });
    if (url === './api/token') {
      if (options.headers.Authorization === 'Bearer first-key') return new Promise(resolve => { finishFirstToken = resolve; });
      return token('second-token');
    }
    if (options.headers.Authorization === 'Bearer first-token') return new Promise(resolve => { finishFirstUpload = resolve; });
    return response({ id: 'second-job' });
  };
  const first = createBatchClient({ apiKey: 'first-key', fetcher }).submit(audioFile(), {});
  const second = createBatchClient({ apiKey: 'second-key', fetcher }).submit(audioFile(), {});
  await new Promise(resolve => setImmediate(resolve));
  const earlyBrokerCalls = calls.filter(call => call.url === './api/token').length;
  finishFirstToken(token('first-token'));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(await second, 'second-job');
  finishFirstUpload(response({ id: 'first-job' }));
  assert.equal(await first, 'first-job');
  assert.equal(earlyBrokerCalls, 1);
  assert.deepEqual(calls.filter(call => call.url === './api/token').map(call => call.authorization), ['Bearer first-key', 'Bearer second-key']);
});

test('a failed broker request releases the queue for the next client', async () => {
  let failFirstToken;
  let brokers = 0;
  const fetcher = async url => {
    if (url !== './api/token') return response({ id: 'recovered-job' });
    if (++brokers === 1) return new Promise((resolve, reject) => { failFirstToken = reject; });
    return token();
  };
  const first = createBatchClient({ fetcher }).submit(audioFile(), {});
  const rejected = assert.rejects(first, error => error.code === 'NETWORK');
  const second = createBatchClient({ fetcher }).submit(audioFile(), {});
  await new Promise(resolve => setImmediate(resolve));
  const beforeFailure = brokers;
  failFirstToken(new Error('offline'));
  await rejected;
  assert.equal(await second, 'recovered-job');
  assert.equal(beforeFailure, 1);
});

test('cancelling a queued authorization rejects promptly without posting or blocking later clients', async () => {
  let finishFirstToken;
  const brokerKeys = [];
  const fetcher = async (url, options) => {
    if (url !== './api/token') return response({ id: 'job' });
    brokerKeys.push(options.headers.Authorization);
    if (brokerKeys.length === 1) return new Promise(resolve => { finishFirstToken = resolve; });
    return token();
  };
  const first = createBatchClient({ apiKey: 'first-key', fetcher }).submit(audioFile(), {});
  const controller = new AbortController();
  const second = createBatchClient({ apiKey: 'cancelled-key', fetcher }).submit(audioFile(), {}, { signal: controller.signal });
  const rejected = assert.rejects(second, { name: 'AbortError' });
  await new Promise(resolve => setImmediate(resolve));
  controller.abort();
  await rejected;
  const third = createBatchClient({ apiKey: 'third-key', fetcher }).submit(audioFile(), {});
  finishFirstToken(token());
  await Promise.all([first, third]);
  assert.deepEqual(brokerKeys, ['Bearer first-key', 'Bearer third-key']);
});

test('a queued broker request receives its timeout only after acquiring its turn', async () => {
  let finishFirstToken;
  let brokers = 0;
  const fetcher = async url => {
    if (url !== './api/token') return response({ id: 'job' });
    if (++brokers === 1) return new Promise(resolve => { finishFirstToken = resolve; });
    return token();
  };
  const first = createBatchClient({ fetcher }).submit(audioFile(), {});
  const second = createBatchClient({ fetcher, requestTimeoutMs: 20 }).submit(audioFile(), {});
  second.catch(() => {});
  await new Promise(resolve => setTimeout(resolve, 50));
  const whileWaiting = brokers;
  finishFirstToken(token());
  await Promise.all([first, second]);
  assert.equal(whileWaiting, 1);
});

test('available Web Locks hold the broker request until the origin-wide lock is acquired', async () => {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis.navigator, 'locks');
  let releaseLock;
  const lock = new Promise(resolve => { releaseLock = resolve; });
  const requests = [];
  const mock = transport([token(), response({ id: 'locked-job' })]);
  const controller = new AbortController();
  Object.defineProperty(globalThis.navigator, 'locks', { configurable: true, value: {
    async request(name, options, callback) { requests.push({ name, options }); await lock; return callback(); },
  } });
  try {
    const result = createBatchClient({ fetcher: mock.fetcher, requestTimeoutMs: 20 }).submit(audioFile(), {}, { signal: controller.signal });
    result.catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 50));
    const beforeRelease = mock.calls.length;
    releaseLock();
    assert.equal(await result, 'locked-job');
    assert.equal(beforeRelease, 0);
    assert.equal(requests.length, 1);
    assert.equal(requests[0].options.mode, 'exclusive');
    assert.equal(requests[0].options.signal, controller.signal);
    assert.ok(requests[0].name.length > 0);
  } finally {
    releaseLock();
    if (descriptor) Object.defineProperty(globalThis.navigator, 'locks', descriptor);
    else delete globalThis.navigator.locks;
  }
});

test('uploads directly to the selected region, sending the long-lived key only to its own token broker', async () => {
  const mock = transport([token(), response({ id: 'job-123' })]);
  const client = createBatchClient({ apiKey: 'long-lived-secret', region: 'us', fetcher: mock.fetcher });
  const config = { type: 'transcription', transcription_config: { model: 'oak-1', language: 'multi' } };
  const progress = [];
  assert.equal(await client.submit(audioFile(), config, { onProgress: value => progress.push(value.phase) }), 'job-123');
  assert.equal(mock.calls[0].url, './api/token');
  assert.equal(mock.calls[0].headers.Authorization, 'Bearer long-lived-secret');
  assert.equal(mock.calls[0].body, '{}');
  assert.equal(mock.calls[0].credentials, 'same-origin');
  assert.equal(mock.calls[0].redirect, 'error');
  assert.equal(mock.calls[0].cache, 'no-store');
  assert.equal(mock.calls[1].url, 'https://us1.asr.api.speechmatics.com/v2/jobs');
  assert.equal(mock.calls[1].headers.Authorization, 'Bearer temporary-token');
  assert.equal(mock.calls[1].headers['Content-Type'], undefined);
  assert.equal(mock.calls[1].credentials, 'omit');
  assert.equal(mock.calls[1].redirect, 'error');
  assert.equal(mock.calls[1].body.get('data_file').name, 'consultation.wav');
  assert.deepEqual(JSON.parse(mock.calls[1].body.get('config')), config);
  assert.deepEqual(progress, ['authorizing', 'uploading', 'submitted']);
});

test('allows a server-configured key without sending an empty Authorization header', async () => {
  const mock = transport([token(), response({ id: 'one' })]);
  const client = createBatchClient({ fetcher: mock.fetcher });
  await client.submit(audioFile(), {});
  assert.equal(mock.calls[0].headers.Authorization, undefined);
  assert.equal(mock.calls[1].url, 'https://eu1.asr.api.speechmatics.com/v2/jobs');
});

test('keeps upload, status, transcript, and cancellation on default EU or the explicitly selected EU/US endpoint', async () => {
  for (const [region, base] of [
    [undefined, 'https://eu1.asr.api.speechmatics.com/v2'],
    ['eu', 'https://eu1.asr.api.speechmatics.com/v2'],
    ['us', 'https://us1.asr.api.speechmatics.com/v2'],
  ]) {
    const mock = transport([token(), response({ id: 'pinned-job' }), response({ job: { status: 'done' } }), response({ results: [] }), response({})]);
    const client = createBatchClient({ ...(region ? { region } : {}), fetcher: mock.fetcher });
    const id = await client.submit(audioFile(), {});
    await client.waitForTranscript(id);
    await client.cancel(id);
    assert.deepEqual(mock.calls.slice(1).map(call => call.url), [
      `${base}/jobs`, `${base}/jobs/pinned-job?wait=0`,
      `${base}/jobs/pinned-job/transcript?format=json-v2&wait=0`, `${base}/jobs/pinned-job`,
    ]);
    assert.deepEqual(mock.calls.slice(1).map(call => call.method), ['POST', 'GET', 'GET', 'DELETE']);
  }
});

test('rejects the unsupported Global endpoint without requesting a token or uploading audio', () => {
  const mock = transport([]);
  assert.throws(() => createBatchClient({ region: 'global', fetcher: mock.fetcher }), /endpoint/i);
  assert.equal(mock.calls.length, 0);
});

test('rejects unrecognised regions and unsafe job identifiers without a network request', async () => {
  const mock = transport([]);
  assert.throws(() => createBatchClient({ region: 'https://other.example', fetcher: mock.fetcher }), /endpoint/i);
  const client = createBatchClient({ fetcher: mock.fetcher });
  await assert.rejects(client.waitForTranscript('../escape'), /job/i);
  await assert.rejects(client.cancel('id?token=secret'), /job/i);
  assert.equal(mock.calls.length, 0);
});

test('does not retry uploads after authorization errors or an uncertain connection failure', async () => {
  for (const failure of [response({ secret: 'private-upstream-details' }, 401), new TypeError('long-lived-secret')]) {
    const mock = transport([token(), failure]);
    const client = createBatchClient({ fetcher: mock.fetcher });
    await assert.rejects(client.submit(audioFile(), {}), error => {
      assert.doesNotMatch(error.message, /private-upstream-details|long-lived-secret/);
      assert.match(error.message, /not retried|before submitting again/);
      return true;
    });
    assert.equal(mock.calls.length, 2);
  }
});

test('server errors during upload warn about uncertain acceptance and never retry', async () => {
  for (const status of [500, 502, 503, 504]) {
    const mock = transport([token(), response({ error: 'private-server-detail' }, status)]);
    await assert.rejects(createBatchClient({ fetcher: mock.fetcher }).submit(audioFile(), {}), error => {
      assert.equal(error.code, 'UPLOAD_UNCERTAIN');
      assert.match(error.message, /Portal before submitting again/);
      assert.doesNotMatch(error.message, /private-server-detail/);
      return true;
    });
    assert.equal(mock.calls.length, 2);
  }
});

test('a missing or invalid key response from the broker points to Settings safely', async () => {
  const mock = transport([response({ error: { code: 'missing_api_key', message: 'private-detail' } }, 400)]);
  await assert.rejects(createBatchClient({ fetcher: mock.fetcher }).submit(audioFile(), {}), error => {
    assert.match(error.message, /Add or check your Speechmatics API key in Settings/);
    assert.doesNotMatch(error.message, /private-detail/);
    return true;
  });
});

test('polls job.status and retrieves the json-v2 transcript when the job finishes', async () => {
  const result = { format: '2.9', results: [] };
  const mock = transport([token(), response({ job: { status: 'running' } }), response({ job: { status: 'done' } }), response(result)]);
  const waits = [], statuses = [];
  const client = createBatchClient({ fetcher: mock.fetcher, sleep: async milliseconds => waits.push(milliseconds) });
  assert.deepEqual(await client.waitForTranscript('one', { onStatus: status => statuses.push(status) }), result);
  assert.deepEqual(statuses, ['running', 'done']);
  assert.deepEqual(waits, [1500]);
  assert.equal(mock.calls[1].url, 'https://eu1.asr.api.speechmatics.com/v2/jobs/one?wait=0');
  assert.equal(mock.calls.at(-1).url, 'https://eu1.asr.api.speechmatics.com/v2/jobs/one/transcript?format=json-v2&wait=0');
});

test('renews before expiry and refreshes an idempotent GET exactly once after a 401', async () => {
  let clock = 0;
  const mock = transport([
    token('first', 40), response({ id: 'one' }),
    token('second'), response({}, 401), token('third'),
    response({ job: { status: 'done' } }), response({ results: [] }),
  ]);
  const client = createBatchClient({ fetcher: mock.fetcher, now: () => clock });
  await client.submit(audioFile(), {});
  clock = 15000;
  await client.waitForTranscript('one');
  assert.equal(mock.calls[3].headers.Authorization, 'Bearer second');
  assert.equal(mock.calls[5].headers.Authorization, 'Bearer third');
  assert.equal(mock.calls.filter(call => call.url === './api/token').length, 3);
});

test('stops after the single GET authorization refresh is rejected', async () => {
  const mock = transport([token(), response({}, 401), token('second'), response({}, 401)]);
  const client = createBatchClient({ fetcher: mock.fetcher });
  await assert.rejects(client.waitForTranscript('one'), /authoris|authoriz|expired/i);
  assert.equal(mock.calls.length, 4);
});

test('uses bounded backoff for rate limits and transient failures, including transcript retrieval', async () => {
  let clock = 0;
  const waits = [];
  const mock = transport([
    token(), response({}, 429, { 'Retry-After': '99999' }), new TypeError('sensitive network error'),
    response({ job: { status: 'done' } }), response({}, 503), response({ results: [] }),
  ]);
  const client = createBatchClient({ fetcher: mock.fetcher, now: () => clock, sleep: async delay => { waits.push(delay); clock += delay; } });
  assert.deepEqual(await client.waitForTranscript('one'), { results: [] });
  assert.equal(waits.length, 3);
  assert.equal(waits[0], 15000);
  assert.ok(waits.every(delay => delay > 0 && delay <= 15000));
});

test('bounds the entire polling period and leaves the upstream job available', async () => {
  let clock = 0;
  const calls = [];
  const client = createBatchClient({
    maxWaitMs: 3000, now: () => clock, sleep: async delay => { clock += delay; },
    fetcher: async (url, options) => { calls.push(options.method); return url === './api/token' ? token() : response({ job: { status: 'running' } }); },
  });
  await assert.rejects(client.waitForTranscript('one'), /time limit|still be processing/i);
  assert.ok(clock <= 3000);
  assert.ok(!calls.includes('DELETE'));
});

test('aborting polling stops local work without deleting, and cancellation uses a fresh independent signal', async () => {
  const controller = new AbortController();
  const mock = transport([token(), response({ job: { status: 'running' } }), response({}, 200), token('new-token'), response({ id: 'new-job' })]);
  const client = createBatchClient({ apiKey: 'private-key', fetcher: mock.fetcher, sleep: async () => { controller.abort(); } });
  await assert.rejects(client.waitForTranscript('one', { signal: controller.signal }), { name: 'AbortError' });
  assert.ok(!mock.calls.some(call => call.method === 'DELETE'));
  await client.cancel('one');
  assert.equal(mock.calls[2].method, 'DELETE');
  assert.notEqual(mock.calls[2].signal, controller.signal);
  assert.equal(mock.calls[2].signal.aborted, false);
  await client.submit(audioFile(), {});
  assert.equal(mock.calls[3].headers.Authorization, undefined, 'cancellation must discard the supplied key');
});

test('cancellation reports deletion failures and retains credentials for retry or resumed polling', async () => {
  const mock = transport([token(), response({}, 503), response({ id: 'new-job' })]);
  const client = createBatchClient({ apiKey: 'private-key', fetcher: mock.fetcher });
  await assert.rejects(client.cancel('one'), /could not|unavailable|processing/i);
  await client.submit(audioFile(), {});
  assert.equal(mock.calls[2].headers.Authorization, 'Bearer temporary-token');
});

test('a missing token broker is not mistaken for a successfully deleted job', async () => {
  const mock = transport([response({}, 404)]);
  await assert.rejects(createBatchClient({ fetcher: mock.fetcher }).cancel('one'), error => error.code === 'TOKEN_ENDPOINT_MISSING');
});

test('includes response body reads in the timeout and does not retry an ambiguous upload response', async () => {
  const unreadable = { ok: true, status: 200, json: async () => { throw new Error('secret'); } };
  const upload = transport([token(), unreadable]);
  await assert.rejects(createBatchClient({ fetcher: upload.fetcher }).submit(audioFile(), {}), error => error.code === 'UPLOAD_UNCERTAIN' && /before submitting again/.test(error.message));
  const stuck = { ok: true, status: 200, json: () => new Promise(() => {}) };
  const mock = transport([stuck]);
  await assert.rejects(createBatchClient({ fetcher: mock.fetcher, requestTimeoutMs: 10 }).submit(audioFile(), {}), error => error.code === 'REQUEST_TIMEOUT');
});

test('returns bounded helpful errors without copying broker or upstream response bodies', async () => {
  for (const [status, pattern] of [[401, /key|authoris|authoriz/i], [403, /Oak 1|access/i], [429, /busy|limit|later/i], [503, /key|configured|unavailable/i]]) {
    const mock = transport([response({ error: { code: 'arbitrary', message: 'private-secret-must-not-leak' } }, status)]);
    const client = createBatchClient({ fetcher: mock.fetcher });
    await assert.rejects(client.submit(audioFile(), {}), error => {
      assert.match(error.message, pattern);
      assert.doesNotMatch(error.message, /private-secret/);
      assert.ok(error.message.length < 350);
      return true;
    });
  }
});

test('rejects failed jobs and malformed data with safe errors', async () => {
  for (const body of [{ job: { status: 'rejected', errors: ['private-record'] } }, { job: { status: 'failed' } }, { job: { status: 'private-record' } }, {}]) {
    const mock = transport([token(), response(body)]);
    const client = createBatchClient({ fetcher: mock.fetcher });
    await assert.rejects(client.waitForTranscript('one'), error => !error.message.includes('private-record'));
  }
  const mock = transport([response({ token: 'bad\r\nheader', expires_in: 600 })]);
  await assert.rejects(createBatchClient({ fetcher: mock.fetcher }).submit(audioFile(), {}), /token|invalid/i);
});
