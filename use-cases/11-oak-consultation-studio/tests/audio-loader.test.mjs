import test from 'node:test';
import assert from 'node:assert/strict';
import { createAudioLoader } from '../public/audio-loader.js';
import { createRecorder } from '../public/audio.js';

function windowTimers() {
  const originals = {};
  const active = new Set();
  const calls = [];
  let nextId = 0;
  for (const name of ['setTimeout', 'clearTimeout', 'setInterval', 'clearInterval']) {
    originals[name] = globalThis[name];
    globalThis[name] = function (...args) {
      assert.ok(this === globalThis, `${name} requires the window receiver`);
      calls.push(name);
      if (name.startsWith('set')) { const id = ++nextId; active.add(id); return id; }
      active.delete(args[0]);
    };
  }
  return { active, calls, restore() { Object.assign(globalThis, originals); } };
}

function browser() {
  const probes = [];
  const timers = new Map();
  const liveUrls = new Set();
  const revoked = [];
  let nextId = 0;
  class AudioProbe extends EventTarget {
    duration = NaN;
    src = '';
    pauses = 0;
    loads = 0;
    listeners = new Set();
    addEventListener(type, callback) { this.listeners.add(callback); super.addEventListener(type, callback); }
    removeEventListener(type, callback) { this.listeners.delete(callback); super.removeEventListener(type, callback); }
    pause() { this.pauses++; }
    load() { this.loads++; }
    removeAttribute(name) { if (name === 'src') this.src = ''; }
    metadata(duration) { this.duration = duration; this.dispatchEvent(new Event('loadedmetadata')); }
  }
  const dependencies = {
    createAudio: () => { const probe = new AudioProbe(); probes.push(probe); return probe; },
    createObjectURL: () => { const url = `blob:audio-${++nextId}`; liveUrls.add(url); return url; },
    revokeObjectURL: url => { liveUrls.delete(url); revoked.push(url); },
    setTimeout: (callback, delay) => { const id = ++nextId; timers.set(id, { callback, delay }); return id; },
    clearTimeout: id => timers.delete(id),
  };
  return { dependencies, probes, timers, liveUrls, revoked };
}

function assertClean(environment, probe) {
  assert.equal(environment.timers.size, 0);
  assert.equal(probe.listeners.size, 0);
  assert.equal(probe.src, '');
  assert.equal(probe.pauses, 1);
  assert.equal(probe.loads, 2);
}

test('dismissing a pending load resolves null and discards late metadata', async () => {
  const environment = browser();
  const loader = createAudioLoader(environment.dependencies);
  const loading = loader.load({ name: 'first.wav' });
  const probe = environment.probes[0];
  loader.cancel();
  loader.cancel();
  probe.metadata(20);
  assert.equal(await loading, null);
  assertClean(environment, probe);
  assert.equal(environment.liveUrls.size, 0);
  assert.equal(environment.revoked.length, 1);
});

test('a replacement load cancels the previous request and preserves the successful URL until released', async () => {
  const environment = browser();
  const loader = createAudioLoader(environment.dependencies);
  const first = loader.load({ name: 'first.wav' });
  const firstProbe = environment.probes[0];
  const second = loader.load({ name: 'second.wav' });
  const secondProbe = environment.probes[1];
  const secondUrl = secondProbe.src;
  firstProbe.metadata(99);
  secondProbe.metadata(12.5);
  assert.equal(await first, null);
  const result = await second;
  assert.equal(result.duration, 12.5);
  assert.equal(result.url, secondUrl);
  loader.cancel();
  assert.deepEqual([...environment.liveUrls], [secondUrl]);
  assertClean(environment, firstProbe);
  assertClean(environment, secondProbe);
  result.release();
  result.release();
  assert.equal(environment.liveUrls.size, 0);
  assert.equal(environment.revoked.filter(url => url === secondUrl).length, 1);
});

test('uses a captured recording duration when the native duration is infinite', async () => {
  const environment = browser();
  const loader = createAudioLoader(environment.dependencies);
  const loading = loader.load({ recordedDuration: 4.75 });
  environment.probes[0].metadata(Infinity);
  const result = await loading;
  assert.equal(result.duration, 4.75);
  assertClean(environment, environment.probes[0]);
  result.release();
});

test('prefers finite native duration over the recording clock', async () => {
  const environment = browser();
  const loading = createAudioLoader(environment.dependencies).load({ recordedDuration: 4 });
  environment.probes[0].metadata(4.2);
  const result = await loading;
  assert.equal(result.duration, 4.2);
  result.release();
});

test('rejects unreadable duration and releases the failed probe and URL', async () => {
  for (const recordedDuration of [undefined, 0, -1, Infinity, NaN]) {
    const environment = browser();
    const loader = createAudioLoader(environment.dependencies);
    const loading = loader.load({ recordedDuration });
    const rejected = assert.rejects(loading, /duration.*WAV|duration.*MP3/i);
    environment.probes[0].metadata(Infinity);
    await rejected;
    assertClean(environment, environment.probes[0]);
    assert.equal(environment.liveUrls.size, 0);
    loader.cancel();
    assert.equal(environment.revoked.length, 1);
  }
});

test('decoder errors reject and clean all pending resources', async () => {
  const environment = browser();
  const loader = createAudioLoader(environment.dependencies);
  const loading = loader.load({});
  const rejected = assert.rejects(loading, /cannot be played.*WAV|cannot be played.*MP3/i);
  environment.probes[0].dispatchEvent(new Event('error'));
  await rejected;
  assertClean(environment, environment.probes[0]);
  assert.equal(environment.liveUrls.size, 0);
  loader.cancel();
  assert.equal(environment.revoked.length, 1);
});

test('times out stalled metadata and permits a fresh successful load', async () => {
  const environment = browser();
  const loader = createAudioLoader(environment.dependencies);
  const loading = loader.load({});
  const rejected = assert.rejects(loading, /too long|timed out/i);
  const timer = [...environment.timers.values()][0];
  assert.equal(timer.delay, 12000);
  timer.callback();
  await rejected;
  assertClean(environment, environment.probes[0]);
  assert.equal(environment.liveUrls.size, 0);
  const retry = loader.load({});
  environment.probes[1].metadata(3);
  const result = await retry;
  assert.equal(result.duration, 3);
  result.release();
});

test('loader default timers preserve the browser window receiver', async () => {
  const environment = browser();
  delete environment.dependencies.setTimeout;
  delete environment.dependencies.clearTimeout;
  const timers = windowTimers();
  try {
    const loader = createAudioLoader(environment.dependencies);
    const loading = loader.load({});
    environment.probes[0].metadata(2);
    const result = await loading;
    assert.equal(result.duration, 2);
    assert.deepEqual(timers.calls, ['setTimeout', 'clearTimeout']);
    assert.equal(timers.active.size, 0);
    result.release();
  } finally { timers.restore(); }
});

test('recorder default timers preserve the browser window receiver and are cleared on cancellation', async () => {
  const timers = windowTimers();
  let stopped = false;
  class NativeRecorder {
    state = 'inactive';
    static isTypeSupported() { return true; }
    start() { this.state = 'recording'; }
    stop() { this.state = 'inactive'; }
  }
  try {
    const recorder = createRecorder({}, {
      mediaDevices: { getUserMedia: async () => ({ getTracks: () => [{ stop() { stopped = true; } }] }) },
      MediaRecorder: NativeRecorder,
    });
    await recorder.start();
    assert.equal(recorder.active, true);
    recorder.cancel();
    assert.equal(recorder.active, false);
    assert.equal(stopped, true);
    assert.deepEqual(timers.calls, ['setInterval', 'setTimeout', 'clearInterval', 'clearTimeout']);
    assert.equal(timers.active.size, 0);
  } finally { timers.restore(); }
});
