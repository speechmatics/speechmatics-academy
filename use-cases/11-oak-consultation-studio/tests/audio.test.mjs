import test from 'node:test';
import assert from 'node:assert/strict';
import { validateAudioFile, createRecorder, seekAudio } from '../public/audio.js';

function browser() {
  const instances = [];
  const intervals = new Map();
  const timeouts = new Map();
  let timerId = 0;
  let clock = 0;
  const track = { stopped: 0, stop() { this.stopped++; } };
  const stream = { getTracks: () => [track] };
  class Recorder {
    static isTypeSupported(type) { return type === 'audio/webm'; }
    constructor(source, options = {}) {
      this.stream = source;
      this.mimeType = options.mimeType || 'audio/ogg';
      this.state = 'inactive';
      this.stops = 0;
      instances.push(this);
    }
    start() { this.state = 'recording'; }
    stop() { this.state = 'inactive'; this.stops++; }
    data(text) { this.ondataavailable?.({ data: new Blob([text], { type: this.mimeType }) }); }
    finish() { this.onstop?.(); }
    fail(error) { this.onerror?.({ error }); }
  }
  const deps = {
    mediaDevices: { async getUserMedia(options) { assert.deepEqual(options, { audio: true }); return stream; } },
    MediaRecorder: Recorder, File,
    now: () => clock,
    setInterval: (callback, delay) => { const id = ++timerId; intervals.set(id, { callback, delay }); return id; },
    clearInterval: id => intervals.delete(id),
    setTimeout: (callback, delay) => { const id = ++timerId; timeouts.set(id, { callback, delay }); return id; },
    clearTimeout: id => timeouts.delete(id),
  };
  return { deps, instances, intervals, timeouts, track, stream, advance: value => { clock = value; } };
}

test('validates extension and size without claiming browser decoding support', () => {
  for (const extension of ['wav', 'mp3', 'm4a', 'ogg', 'flac', 'aac', 'mp4', 'webm']) {
    assert.equal(validateAudioFile({ name: `sample.${extension.toUpperCase()}`, size: 100 * 1024 * 1024 }), null);
  }
  assert.match(validateAudioFile({ name: 'empty.wav', size: 0 }), /empty/i);
  assert.match(validateAudioFile({ name: 'large.mp3', size: 100 * 1024 * 1024 + 1 }), /100/);
  assert.match(validateAudioFile({ name: 'file.exe', size: 4 }), /format|supported|extension/i);
  assert.match(validateAudioFile(null), /file/i);
  assert.notEqual(validateAudioFile({ name: 'bad.wav', size: NaN }), null);
});

test('seeks recorded WebM using the accepted UI duration even when native duration is infinite', () => {
  const audio = { duration: Infinity, currentTime: 0 };
  assert.equal(seekAudio(audio, 4.5, 12), true);
  assert.equal(audio.currentTime, 4.5);
  assert.equal(seekAudio(audio, -2, 12), true);
  assert.equal(audio.currentTime, 0);
  assert.equal(seekAudio(audio, 20, 12), true);
  assert.equal(audio.currentTime, 12);
});

test('leaves playback untouched for invalid seek values or an unavailable timeline', () => {
  const audio = { duration: Infinity, currentTime: 3 };
  for (const [time, duration] of [[NaN, 12], [Infinity, 12], ['4', 12], [4, Infinity], [4, NaN], [4, 0], [4, -2]]) {
    assert.equal(seekAudio(audio, time, duration), false);
    assert.equal(audio.currentTime, 3);
  }
  assert.equal(seekAudio(null, 4, 12), false);
});

test('reports a browser seek rejection without throwing', () => {
  const audio = { duration: Infinity, set currentTime(value) { throw new DOMException('Timeline unavailable', 'InvalidStateError'); } };
  assert.equal(seekAudio(audio, 4, 12), false);
});

test('records final chunks once and releases tracks and timers after normal stop', async () => {
  const environment = browser();
  const files = [];
  const ticks = [];
  const recorder = createRecorder({ onStopped: file => files.push(file), onTick: value => ticks.push(value) }, environment.deps);
  assert.equal(recorder.active, false);
  await recorder.start();
  assert.equal(recorder.active, true);
  const native = environment.instances[0];
  assert.equal(native.mimeType, 'audio/webm');
  native.data('first');
  environment.advance(2200);
  for (const timer of environment.intervals.values()) timer.callback();
  assert.equal(ticks.at(-1), 2.2);
  recorder.stop();
  recorder.stop();
  assert.equal(native.stops, 1);
  assert.equal(recorder.active, false);
  assert.equal(files.length, 0);
  native.data('final');
  native.finish();
  native.finish();
  assert.equal(files.length, 1);
  assert.ok(files[0] instanceof File);
  assert.equal(files[0].type, 'audio/webm');
  assert.match(files[0].name, /\.webm$/);
  assert.equal(await files[0].text(), 'firstfinal');
  assert.equal(environment.track.stopped, 1);
  assert.equal(environment.intervals.size, 0);
  assert.equal(environment.timeouts.size, 0);
});

test('captures precise recording duration at stop instead of the last timer tick', async () => {
  const environment = browser();
  const recorder = createRecorder({}, environment.deps);
  assert.equal(recorder.recordedDuration, 0);
  await recorder.start();
  environment.advance(2200);
  for (const timer of environment.intervals.values()) timer.callback();
  environment.advance(2356);
  assert.equal(recorder.recordedDuration, 2.356);
  recorder.stop();
  environment.advance(2800);
  environment.instances[0].finish();
  assert.equal(recorder.recordedDuration, 2.356);
});

test('cancellation discards data and releases an active microphone', async () => {
  const environment = browser();
  const files = [];
  const recorder = createRecorder({ onStopped: file => files.push(file) }, environment.deps);
  await recorder.start();
  const native = environment.instances[0];
  native.data('discard');
  recorder.cancel();
  recorder.cancel();
  native.data('final');
  native.finish();
  assert.equal(files.length, 0);
  assert.equal(recorder.active, false);
  assert.equal(native.stops, 1);
  assert.equal(environment.track.stopped, 1);
  assert.equal(environment.intervals.size + environment.timeouts.size, 0);
});

test('cancellation while permission is pending releases the eventual stream without starting', async () => {
  const environment = browser();
  let acquire;
  environment.deps.mediaDevices.getUserMedia = () => new Promise(resolve => { acquire = resolve; });
  const files = [];
  const recorder = createRecorder({ onStopped: file => files.push(file) }, environment.deps);
  const start = recorder.start();
  recorder.cancel();
  acquire(environment.stream);
  assert.equal(await start, false);
  assert.equal(environment.instances.length, 0);
  assert.equal(environment.track.stopped, 1);
  assert.equal(files.length, 0);
});

test('startup rejection is handled by its caller without duplicate error callbacks', async () => {
  const environment = browser();
  const denied = new Error('Permission denied');
  environment.deps.mediaDevices.getUserMedia = async () => { throw denied; };
  const errors = [];
  const recorder = createRecorder({ onError: error => errors.push(error) }, environment.deps);
  await assert.rejects(recorder.start(), /Permission denied/);
  assert.equal(errors.length, 0);
  assert.equal(recorder.active, false);
  assert.equal(environment.intervals.size + environment.timeouts.size, 0);
});

test('a recorder startup failure releases the already acquired microphone', async () => {
  const environment = browser();
  environment.deps.MediaRecorder.prototype.start = () => { throw new Error('Unsupported recording device'); };
  const recorder = createRecorder({}, environment.deps);
  await assert.rejects(recorder.start(), /Unsupported recording device/);
  assert.equal(environment.track.stopped, 1);
  assert.equal(recorder.active, false);
  assert.equal(environment.intervals.size + environment.timeouts.size, 0);
});

test('uses an available MP4 recording format when WebM is unsupported', async () => {
  const environment = browser();
  environment.deps.MediaRecorder.isTypeSupported = type => type === 'audio/mp4';
  const files = [];
  const recorder = createRecorder({ onStopped: file => files.push(file) }, environment.deps);
  await recorder.start();
  const native = environment.instances[0];
  native.data('audio');
  recorder.stop();
  native.finish();
  assert.equal(files[0].type, 'audio/mp4');
  assert.match(files[0].name, /\.m4a$/);
});

test('runtime errors notify once and discard the failed recording', async () => {
  const environment = browser();
  const errors = [];
  const files = [];
  const recorder = createRecorder({ onError: error => errors.push(error), onStopped: file => files.push(file) }, environment.deps);
  await recorder.start();
  const native = environment.instances[0];
  native.data('broken');
  native.fail(new Error('Device lost'));
  native.fail(new Error('Device lost again'));
  native.finish();
  assert.equal(errors.length, 1);
  assert.match(errors[0].message, /Device lost/);
  assert.equal(files.length, 0);
  assert.equal(recorder.active, false);
  assert.equal(environment.track.stopped, 1);
  assert.equal(environment.intervals.size + environment.timeouts.size, 0);
});

test('automatically stops at five minutes and returns the complete final file', async () => {
  const environment = browser();
  const files = [];
  const recorder = createRecorder({ onStopped: file => files.push(file) }, environment.deps);
  await recorder.start();
  const timeout = [...environment.timeouts.values()][0];
  assert.equal(timeout.delay, 300000);
  environment.advance(300000);
  timeout.callback();
  const native = environment.instances[0];
  assert.equal(native.stops, 1);
  native.data('last chunk');
  native.finish();
  assert.equal(await files[0].text(), 'last chunk');
  assert.equal(environment.track.stopped, 1);
});

test('concurrent starts acquire one stream and a later start creates a fresh session', async () => {
  const environment = browser();
  let requests = 0;
  environment.deps.mediaDevices.getUserMedia = async () => { requests++; return environment.stream; };
  const recorder = createRecorder({}, environment.deps);
  await Promise.all([recorder.start(), recorder.start()]);
  assert.equal(requests, 1);
  recorder.cancel();
  await recorder.start();
  assert.equal(requests, 2);
  assert.equal(environment.instances.length, 2);
  recorder.cancel();
});
