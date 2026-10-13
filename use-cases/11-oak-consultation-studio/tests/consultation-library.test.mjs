import test from 'node:test';
import assert from 'node:assert/strict';
import { createConsultationLibrary } from '../public/consultation-library.js';
import { createTranscriptionSession } from '../public/transcription-session.js';

const tick = () => new Promise(resolve => setImmediate(resolve));
const file = name => new File(['audio'], name, { type: 'audio/wav' });
function media(name, duration = 30) {
  return { url: `blob:${name}`, duration, releases: 0, release() { this.releases++; } };
}

function environment() {
  let ids = 0;
  const clients = [];
  const progress = [];
  const library = createConsultationLibrary({
    createId: () => `consultation-${++ids}`,
    now: () => new Date('2026-10-13T12:34:56Z'),
    createSession: ({ onChange }) => createTranscriptionSession({
      onChange, prepareAudio: async audio => audio,
      normalize: (result, metadata) => ({ id: 'batch-generated-id', ...metadata, transcribed: true, utterances: result.utterances }),
      createClient: options => {
        const index = clients.length;
        const client = {
          options, submissions: [], waits: [], clears: 0, cancellations: [],
          submit: async (audio, config) => { client.submissions.push({ audio, config }); return `job-${index}`; },
          waitForTranscript: jobId => { client.waits.push(jobId); return new Promise((resolve, reject) => { client.finish = resolve; client.fail = reject; }); },
          clearCredentials: () => client.clears++,
          cancel: async jobId => client.cancellations.push(jobId),
        };
        clients.push(client);
        return client;
      },
    }),
    onChange: (entry, status) => {
      assert.equal(library.get(entry.sample.id), entry, 'entries exist before change callbacks');
      progress.push({ entry, status });
    },
  });
  return { library, clients, progress };
}

for (const source of ['recording', 'upload']) test(`two ${source}s automatically transcribe and retain distinct IDs, files, media, sessions, and completed transcripts`, async () => {
  const { library, clients } = environment();
  const firstFile = file('consultation-recording.wav'), secondFile = file('consultation-recording.wav');
  const firstMedia = media('first'), secondMedia = media('second');
  const first = library.add(firstFile, firstMedia, { source, apiKey: 'first-key' });
  const second = library.add(secondFile, secondMedia, { source, apiKey: 'second-key' });
  const firstSample = first.sample, secondSample = second.sample;
  assert.notEqual(first.sample.id, second.sample.id);
  assert.equal(first.sample.region, 'eu');
  assert.equal(second.sample.region, 'eu');
  assert.notEqual(first.session, second.session);
  assert.equal(first.file, firstFile);
  assert.equal(second.file, secondFile);
  assert.equal(first.media, firstMedia);
  assert.equal(second.media, secondMedia);
  if (source === 'recording') assert.match(first.sample.title, /^Consultation · /);
  else assert.equal(first.sample.title, firstFile.name);
  await tick();
  assert.equal(clients.length, 2);
  assert.equal(clients[0].submissions[0].audio, firstFile);
  assert.equal(clients[1].submissions[0].audio, secondFile);
  assert.equal(clients[0].options.apiKey, 'first-key');
  assert.equal(clients[1].options.apiKey, 'second-key');
  assert.equal(clients[0].options.region, 'eu');
  assert.equal(clients[1].options.region, 'eu');
  const firstWords = [{ id: 'first-turn', words: [{ text: 'First' }] }];
  const secondWords = [{ id: 'second-turn', words: [{ text: 'Second' }] }];
  clients[1].finish({ utterances: secondWords });
  await tick();
  clients[0].finish({ utterances: firstWords });
  await tick();
  assert.equal(first.sample, firstSample);
  assert.equal(second.sample, secondSample);
  assert.equal(first.sample.id, 'local-consultation-1');
  assert.equal(second.sample.id, 'local-consultation-2');
  assert.deepEqual(first.sample.utterances, firstWords);
  assert.deepEqual(second.sample.utterances, secondWords);
  assert.equal(firstMedia.releases + secondMedia.releases, 0);
  assert.deepEqual(library.entries(), [first, second]);
});

test('uploads automatically use the supplied key and current configuration without duplicate submissions', async () => {
  const { library, clients } = environment();
  const upload = library.add(file('uploaded-audio.wav'), media('upload', 42), { apiKey: 'upload-key' });
  assert.equal(upload.sample.title, 'uploaded-audio.wav');
  assert.equal(upload.sample.region, 'eu');
  assert.equal(clients.length, 0, 'startup waits for the caller to select and configure the new entry');
  Object.assign(upload.sample, { region: 'us', locale: 'en-US', diarization: 'channel', hints: ['en', 'es'] });
  await tick();
  assert.equal(clients.length, 1, 'no second click is required to start the upload');
  assert.deepEqual(clients[0].options, { apiKey: 'upload-key', region: 'us' });
  assert.deepEqual(clients[0].submissions[0].config, {
    type: 'transcription', transcription_config: { model: 'oak-1', language: 'multi', diarization: 'channel', output_locale: 'en-US', language_hints: ['en', 'es'] },
  });
  const task = library.transcribe(upload.sample.id, { apiKey: 'another-key' });
  assert.equal(clients.length, 1, 'a manual start cannot duplicate the active automatic job');
  clients[0].finish({ utterances: [] });
  await task;
  assert.equal(upload.sample.duration, 42);
  assert.equal(upload.sample.region, 'us');
  await library.transcribe(upload.sample.id, { apiKey: 'another-key' });
  assert.equal(clients.length, 1);
  assert.equal(clients[0].submissions.length, 1);
});

test('renaming during transcription survives completion and keeps the same mutable sample', async () => {
  const { library, clients, progress } = environment();
  const entry = library.add(file('original.wav'), media('renaming'));
  const originalSample = entry.sample;
  const task = library.transcribe(entry.sample.id);
  await tick();
  assert.equal(library.rename(entry.sample.id, '  Review with patient  '), 'Review with patient');
  assert.equal(progress.at(-1).status.status, 'renamed');
  clients[0].finish({ utterances: [{ id: 'completed-turn', words: [] }] });
  await task;
  assert.equal(entry.sample, originalSample);
  assert.equal(entry.sample.title, 'Review with patient');
  assert.equal(entry.sample.id, 'local-consultation-1');
  assert.throws(() => library.rename(entry.sample.id, '   '), /title|name/i);
  assert.equal(entry.sample.title, 'Review with patient');
  assert.equal(Array.from(library.rename(entry.sample.id, 'a'.repeat(125))).length, 120);
});

test('resume belongs to the selected entry and never resubmits either consultation', async () => {
  const { library, clients } = environment();
  const first = library.add(file('first.wav'), media('first'));
  const second = library.add(file('second.wav'), media('second'));
  const firstTask = library.transcribe(first.sample.id, { apiKey: 'first-key' });
  const secondTask = library.transcribe(second.sample.id, { apiKey: 'second-key' });
  await tick();
  clients[0].fail(new Error('Connection interrupted'));
  clients[1].finish({ utterances: [{ id: 'second-result' }] });
  await Promise.all([firstTask, secondTask]);
  assert.equal(first.session.state.canResume, true);
  const resume = library.transcribe(first.sample.id, { apiKey: 'updated-first-key' });
  await tick();
  assert.equal(clients.length, 3);
  assert.equal(clients[2].options.apiKey, 'updated-first-key');
  assert.deepEqual(clients[2].waits, ['job-0']);
  assert.equal(clients[2].submissions.length, 0);
  clients[2].finish({ utterances: [{ id: 'first-result' }] });
  await resume;
  assert.equal(first.sample.utterances[0].id, 'first-result');
  assert.equal(second.sample.utterances[0].id, 'second-result');
  assert.equal(clients[0].submissions.length + clients[1].submissions.length, 2);
});

test('stopWaiting reaches every session and releaseAll releases every media URL exactly once', () => {
  const sessions = [];
  const library = createConsultationLibrary({
    createId: () => 'same-generated-id',
    createSession: () => {
      const session = { stopped: 0, state: { status: 'ready' }, stopWaiting() { this.stopped++; } };
      sessions.push(session);
      return session;
    },
  });
  const firstMedia = media('one'), secondMedia = media('two');
  const first = library.add(file('one.wav'), firstMedia), second = library.add(file('two.wav'), secondMedia);
  assert.notEqual(first.sample.id, second.sample.id, 'even repeated generated IDs cannot replace an entry');
  library.stopWaiting();
  assert.deepEqual(sessions.map(session => session.stopped), [1, 1]);
  assert.equal(firstMedia.releases + secondMedia.releases, 0, 'page pauses retain playable media');
  library.releaseAll();
  library.releaseAll();
  assert.equal(firstMedia.releases, 1);
  assert.equal(secondMedia.releases, 1);
});

test('callbacks produced synchronously by a session factory wait until registration', () => {
  let callbackEntry;
  const library = createConsultationLibrary({
    createId: () => 'synchronous',
    createSession: ({ onChange }) => {
      onChange({ status: 'ready' });
      return { state: { status: 'ready' } };
    },
    onChange: entry => { assert.equal(library.get(entry.sample.id), entry); callbackEntry = entry; },
  });
  const entry = library.add(file('sample.wav'), media('sample'));
  assert.equal(callbackEntry, entry);
  const copy = library.entries();
  copy.length = 0;
  assert.equal(library.entries().length, 1);
  library.releaseAll();
});

test('releasing the library before queued upload startup prevents any remote job', async () => {
  const { library, clients } = environment();
  const audio = media('released-upload');
  library.add(file('released.wav'), audio, { apiKey: 'upload-key' });
  library.releaseAll();
  await tick();
  assert.equal(clients.length, 0);
  assert.equal(audio.releases, 1);
});

test('an upload without a browser key automatically uses the environment credential path', async () => {
  const { library, clients } = environment();
  const upload = library.add(file('environment.wav'), media('environment-upload'));
  await tick();
  assert.equal(clients.length, 1);
  assert.equal(clients[0].options.apiKey, '');
  assert.equal(clients[0].submissions.length, 1);
  clients[0].finish({ utterances: [] });
  await tick();
  assert.equal(upload.sample.transcribed, true);
});

test('automatic upload startup errors are surfaced and allow an explicit retry with a newly saved key', async () => {
  const progress = [];
  const starts = [];
  const library = createConsultationLibrary({
    createId: () => 'retry',
    createSession: () => ({
      state: { status: 'ready' },
      start(audio, options) {
        starts.push({ audio, options });
        if (!options.apiKey) throw new Error('Add your Speechmatics API key in Settings.');
      },
    }),
    onChange: (entry, status) => progress.push({ entry, status }),
  });
  const audio = file('retry.wav');
  const upload = library.add(audio, media('retry'));
  await tick();
  assert.equal(starts.length, 1);
  assert.equal(progress.at(-1).entry, upload);
  assert.equal(progress.at(-1).status.status, 'error');
  assert.equal(progress.at(-1).status.canResume, false);
  assert.match(progress.at(-1).status.message, /API key/);
  await library.transcribe(upload.sample.id, { apiKey: 'newly-saved-key' });
  assert.equal(starts.length, 2);
  assert.equal(starts[1].audio, audio);
  assert.equal(starts[1].options.apiKey, 'newly-saved-key');
  assert.equal(library.entries().length, 1);
});
