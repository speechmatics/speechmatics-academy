import test from 'node:test';
import assert from 'node:assert/strict';
import { createTranscriptionSession } from '../public/transcription-session.js';
import { createBatchClient } from '../public/batch-client.js';

function harness(client = {}) {
  const changes = [];
  let submissions = 0;
  const api = { submit: async () => { submissions++; return 'job1'; }, waitForTranscript: async () => ({ results: [] }), cancel: async () => {}, clearCredentials() {}, ...client };
  const session = createTranscriptionSession({
    createClient: () => api, prepareAudio: async file => file,
    normalize: (result, metadata) => ({ ...metadata, transcribed: true, result }),
    onChange: state => changes.push(state),
  });
  return { session, changes, submissions: () => submissions };
}

test('completed sessions retain actual job metadata and cannot upload twice concurrently', async () => {
  const h = harness();
  const first = h.session.start({ name: 'test.wav' }, { metadata: { title: 'Test' } });
  await h.session.start({ name: 'other.wav' });
  await first;
  assert.equal(h.submissions(), 1);
  assert.equal(h.session.state.status, 'done');
  assert.equal(h.session.state.sample.jobId, 'job1');
  assert.equal(h.session.state.sample.title, 'Test');
  assert.equal(h.session.state.sample.region, 'eu');
});

test('polling failures resume the same job without another paid upload', async () => {
  let polls = 0;
  const h = harness({ waitForTranscript: async () => { if (++polls === 1) throw new Error('Network unavailable'); return { results: [] }; } });
  await h.session.start({ name: 'test.wav' });
  assert.equal(h.session.state.status, 'error');
  assert.equal(h.session.state.canResume, true);
  await h.session.resume();
  assert.equal(h.session.state.status, 'done');
  assert.equal(h.submissions(), 1);
});

test('cancelling a known job waits for deletion and suppresses late transcript results', async () => {
  let complete;
  let cancelledId;
  const h = harness({ waitForTranscript: () => new Promise(resolve => { complete = resolve; }), cancel: async id => { cancelledId = id; } });
  const run = h.session.start({ name: 'test.wav' });
  await new Promise(resolve => setImmediate(resolve));
  await h.session.cancel();
  complete({ results: [] });
  await run;
  assert.equal(cancelledId, 'job1');
  assert.equal(h.session.state.status, 'cancelled');
  assert.equal(h.session.state.sample, undefined);
});

test('cancel failure retains a resumable job and says it may still be running', async () => {
  const h = harness({ waitForTranscript: async () => { throw new Error('Offline'); }, cancel: async () => { throw new Error('Offline'); } });
  await h.session.start({ name: 'test.wav' });
  await h.session.cancel();
  assert.equal(h.session.state.status, 'error');
  assert.equal(h.session.state.canResume, true);
  assert.match(h.session.state.message, /may still be running/);
});

test('cancel during conversion never submits audio', async () => {
  let finishConversion;
  let submitted = false;
  const session = createTranscriptionSession({
    prepareAudio: () => new Promise(resolve => { finishConversion = resolve; }),
    createClient: () => ({ submit: async () => { submitted = true; }, clearCredentials() {} }),
    normalize: value => value,
  });
  const run = session.start({ name: 'test.webm' });
  await session.cancel();
  finishConversion({ name: 'test.wav' });
  await run;
  assert.equal(submitted, false);
  assert.equal(session.state.status, 'cancelled');
});

test('resuming with updated credentials retains the original job region without uploading again', async () => {
  const clientOptions = [];
  const polls = [];
  const clears = [];
  let submissions = 0;
  const session = createTranscriptionSession({
    prepareAudio: async file => file,
    createClient: options => {
      const index = clientOptions.length;
      clientOptions.push(options);
      return {
        submit: async () => { submissions++; return 'original-job'; },
        waitForTranscript: async jobId => {
          polls.push({ index, jobId });
          if (index === 0) throw new Error('API key expired');
          return { results: [] };
        },
        clearCredentials: () => clears.push(index),
      };
    },
    normalize: (result, metadata) => ({ result, ...metadata }),
  });
  await session.start({ name: 'test.wav' }, { apiKey: 'stale-key', region: 'us', metadata: { title: 'Original' } });
  await session.resume({ apiKey: 'corrected-key', region: 'eu' });
  assert.deepEqual(clientOptions, [{ apiKey: 'stale-key', region: 'us' }, { apiKey: 'corrected-key', region: 'us' }]);
  assert.deepEqual(polls, [{ index: 0, jobId: 'original-job' }, { index: 1, jobId: 'original-job' }]);
  assert.equal(submissions, 1);
  assert.deepEqual(clears, [0, 1]);
  assert.equal(session.state.status, 'done');
  assert.equal(session.state.sample.region, 'us');
  assert.equal(session.state.sample.title, 'Original');
});

test('invalid responses for a known job remain resumable without another upload', async () => {
  let calls = 0;
  const h = harness({ waitForTranscript: async () => {
    if (++calls === 1) throw Object.assign(new Error('Unreadable response'), { code: 'INVALID_RESPONSE' });
    return { results: [] };
  } });
  await h.session.start({ name: 'test.wav' });
  assert.equal(h.session.state.canResume, true);
  assert.equal(h.session.state.jobId, 'job1');
  await h.session.resume();
  assert.equal(h.session.state.status, 'done');
  assert.equal(h.submissions(), 1);
});

test('a late cancelled upload deletes through its own client without touching a newer session', async () => {
  let finishOldUpload;
  let finishNewPoll;
  const clients = [];
  const cancellations = [];
  const clears = [];
  const session = createTranscriptionSession({
    prepareAudio: async file => file,
    createClient: options => {
      const index = clients.length;
      const client = {
        submit: async (file, config, { onProgress }) => {
          onProgress({ phase: 'uploading' });
          return index === 0 ? new Promise(resolve => { finishOldUpload = resolve; }) : 'new-job';
        },
        waitForTranscript: () => new Promise(resolve => { finishNewPoll = resolve; }),
        cancel: async jobId => { cancellations.push({ index, jobId }); },
        clearCredentials: () => clears.push(index),
      };
      clients.push({ client, options });
      return client;
    },
    normalize: (result, metadata) => ({ result, ...metadata }),
  });
  const oldRun = session.start({ name: 'old.wav' }, { apiKey: 'old-key', region: 'eu' });
  await new Promise(resolve => setImmediate(resolve));
  await session.cancel();
  const newRun = session.start({ name: 'new.wav' }, { apiKey: 'new-key', region: 'us' });
  await new Promise(resolve => setImmediate(resolve));
  finishOldUpload('old-job');
  await oldRun;
  assert.deepEqual(cancellations, [{ index: 0, jobId: 'old-job' }]);
  assert.ok(!clears.includes(1));
  assert.equal(session.state.status, 'running');
  assert.equal(session.state.jobId, 'new-job');
  finishNewPoll({ results: [] });
  await newRun;
  assert.equal(session.state.status, 'done');
  assert.equal(session.state.sample.jobId, 'new-job');
  assert.equal(session.state.sample.region, 'us');
});

test('stopping local waits makes a known job resumable and never deletes it', async () => {
  let finishPoll;
  let cancellations = 0;
  let clears = 0;
  const h = harness({
    waitForTranscript: () => new Promise(resolve => { finishPoll = resolve; }),
    cancel: async () => { cancellations++; },
    clearCredentials: () => { clears++; },
  });
  const run = h.session.start({ name: 'test.wav' });
  await new Promise(resolve => setImmediate(resolve));
  h.session.stopWaiting();
  assert.equal(h.session.busy, false);
  assert.equal(h.session.state.status, 'error');
  assert.equal(h.session.state.canResume, true);
  assert.equal(h.session.state.jobId, 'job1');
  assert.match(h.session.state.message, /Reconnect/);
  assert.equal(cancellations, 0);
  assert.equal(clears, 0, 'paused jobs retain their original client credentials for cancellation');
  finishPoll({ results: [] });
  await run;
  assert.equal(h.session.state.status, 'error');
});

test('cancelling a paused job renews with its original key and never falls back to the server key', async () => {
  let clock = 0;
  let tokens = 0;
  const calls = [];
  const fetcher = async (url, options) => {
    calls.push({ url, method: options.method, authorization: options.headers.Authorization });
    if (url === './api/token') {
      assert.equal(options.headers.Authorization, 'Bearer original-key');
      return Response.json({ token: `original-token-${++tokens}`, expires_in: 600 });
    }
    if (options.method === 'POST') return Response.json({ id: 'original-job' });
    if (options.method === 'GET') return new Promise(() => {});
    if (options.method === 'DELETE') return new Response(null, { status: 204 });
    assert.fail('Unexpected request');
  };
  const session = createTranscriptionSession({
    createClient: options => createBatchClient({ ...options, fetcher, now: () => clock }),
    prepareAudio: async file => file,
    normalize: result => result,
  });
  const run = session.start(new File(['audio'], 'test.wav'), { apiKey: 'original-key', region: 'us', config: {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(session.state.jobId, 'original-job');
  session.stopWaiting();
  await run;
  clock = 601000; // The original temporary token expires while the page is paused.
  await session.cancel();
  assert.equal(session.state.status, 'cancelled');
  assert.equal(tokens, 2);
  assert.deepEqual(calls.filter(call => call.url === './api/token').map(call => call.authorization), ['Bearer original-key', 'Bearer original-key']);
  assert.deepEqual(calls.at(-1), {
    url: 'https://us1.asr.api.speechmatics.com/v2/jobs/original-job',
    method: 'DELETE', authorization: 'Bearer original-token-2',
  });
});

test('stopping local upload tracking warns about uncertainty and does not delete a late job', async () => {
  let finishUpload;
  let cancellations = 0;
  const h = harness({
    submit: (file, config, { onProgress }) => {
      onProgress({ phase: 'uploading' });
      return new Promise(resolve => { finishUpload = resolve; });
    },
    cancel: async () => { cancellations++; },
  });
  const run = h.session.start({ name: 'test.wav' });
  await new Promise(resolve => setImmediate(resolve));
  h.session.stopWaiting();
  assert.equal(h.session.busy, false);
  assert.equal(h.session.state.canResume, false);
  assert.match(h.session.state.message, /Portal before submitting/);
  finishUpload('late-job');
  await run;
  assert.equal(cancellations, 0);
  assert.equal(h.session.state.jobId, 'late-job');
  assert.equal(h.session.state.canResume, true);
});

test('abandoning a failed polling session clears tracking without deleting or resubmitting', async () => {
  let cancellations = 0;
  let clears = 0;
  const h = harness({
    waitForTranscript: async () => { throw new Error('Access denied'); },
    cancel: async () => { cancellations++; },
    clearCredentials: () => { clears++; },
  });
  await h.session.start({ name: 'test.wav' });
  assert.equal(h.session.abandon(), true);
  assert.equal(h.session.state.status, 'cancelled');
  assert.equal(h.session.state.canResume, false);
  assert.equal(h.session.state.jobId, undefined);
  assert.equal(h.session.state.sample, undefined);
  assert.match(h.session.state.message, /not cancelled and may still run/);
  assert.equal(clears, 1);
  assert.equal(cancellations, 0);
  assert.equal(h.submissions(), 1);
});

test('abandon refuses to discard an actively running session', async () => {
  let finishPoll;
  const h = harness({ waitForTranscript: () => new Promise(resolve => { finishPoll = resolve; }) });
  const run = h.session.start({ name: 'test.wav' });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.session.abandon(), false);
  assert.equal(h.session.busy, true);
  finishPoll({ results: [] });
  await run;
  assert.equal(h.session.state.status, 'done');
});
