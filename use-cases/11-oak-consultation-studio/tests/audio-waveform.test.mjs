import test from 'node:test';
import assert from 'node:assert/strict';
import { WAVEFORM_BARS, getAudioPeaks, createAudioWaveform } from '../public/audio-waveform.js';

function buffer(channels) {
  const data = channels.map(channel => Float32Array.from(channel));
  return { length: data[0]?.length || 0, numberOfChannels: data.length, sampleRate: 8000, getChannelData: channel => data[channel] };
}

const audioFile = () => new File(['original audio'], 'consultation.wav', { type: 'audio/wav' });

test('uses measured PCM peaks in successive time bins instead of a fixed or synthetic waveform', () => {
  const peaks = getAudioPeaks(buffer([[0, 0.125, -0.25, 0.1, 0, -0.5, 1, 0.2]]), { barCount: 4 });
  assert.deepEqual(Array.from(peaks), [0.125, 0.25, 0.5, 1]);
});

test('keeps silent intervals and a final transient in the correct time bins', () => {
  const peaks = getAudioPeaks(buffer([[0, 0, 0, 0, -0.5]]), { barCount: 3 });
  assert.deepEqual(Array.from(peaks), [0, 0, 1]);
});

test('normalizes quiet recordings while preserving their relative loudness', () => {
  const peaks = getAudioPeaks(buffer([[0, 1 / 8192, -1 / 4096, 0, -1 / 2048, 0, 1 / 1024, 0]]), { barCount: 4 });
  assert.deepEqual(Array.from(peaks), [0.125, 0.25, 0.5, 1]);
});

test('retains sound in opposite-phase channels and in channels other than the first', () => {
  const peaks = getAudioPeaks(buffer([[0.25, -0.5, 0], [-0.25, 0.5, 1]]), { barCount: 3 });
  assert.deepEqual(Array.from(peaks), [0.25, 0.5, 1]);
});

test('spreads clips shorter than the bar count over the whole waveform', () => {
  assert.deepEqual(Array.from(getAudioPeaks(buffer([[0.5, -1]]), { barCount: 4 })), [0.5, 0.5, 1, 1]);
});

test('silent and empty audio stays at zero with the default display length', () => {
  for (const input of [buffer([[0, 0]]), buffer([[]]), buffer([]), null, {}]) {
    const peaks = getAudioPeaks(input);
    assert.equal(peaks.length, WAVEFORM_BARS);
    assert.ok(peaks.every(peak => peak === 0));
  }
});

test('ignores non-finite PCM values and safely handles invalid channel data', () => {
  assert.deepEqual(Array.from(getAudioPeaks(buffer([[NaN, Infinity, -Infinity, 0.5]]), { barCount: 2 })), [0, 1]);
  const invalid = { length: 4, numberOfChannels: 1, getChannelData() { throw new Error('unavailable'); } };
  assert.deepEqual(Array.from(getAudioPeaks(invalid, { barCount: 2 })), [0, 0]);
  for (const barCount of [0, -1, NaN, Infinity, 1.5]) {
    assert.throws(() => getAudioPeaks(buffer([[1]]), { barCount }), RangeError);
  }
});

test('decodes locally at a lower preview sample rate, returns peaks, closes, and preserves the file', async () => {
  const file = audioFile();
  let closed = 0;
  class Decoder {
    constructor(options) { assert.equal(options.sampleRate, 8000); }
    async decodeAudioData(bytes) {
      assert.equal(new TextDecoder().decode(bytes), 'original audio');
      return buffer([[0, 0.25, -0.5, 1]]);
    }
    async close() { closed++; }
  }
  const peaks = await createAudioWaveform(file, { AudioContextClass: Decoder, barCount: 4 });
  assert.deepEqual(Array.from(peaks), [0, 0.25, 0.5, 1]);
  assert.equal(closed, 1);
  assert.equal(await file.text(), 'original audio');
  assert.equal(file.name, 'consultation.wav');
});

test('falls back to the default sample rate when the browser rejects 8 kHz', async () => {
  let closed = false;
  class Decoder {
    constructor(options) {
      if (options?.sampleRate) throw new DOMException('unsupported sample rate', 'NotSupportedError');
    }
    async decodeAudioData() { return buffer([[0, 1]]); }
    async close() { closed = true; }
  }
  assert.deepEqual(Array.from(await createAudioWaveform(audioFile(), { AudioContextClass: Decoder, barCount: 2 })), [0, 1]);
  assert.equal(closed, true);
});

test('reports safe decoder errors and closes even when decoding or shutdown fails', async () => {
  let closed = 0;
  class Decoder {
    async decodeAudioData() { throw new Error('private decoder detail'); }
    async close() { closed++; throw new Error('private shutdown detail'); }
  }
  await assert.rejects(createAudioWaveform(audioFile(), { AudioContextClass: Decoder }), error => {
    assert.match(error.message, /waveform|decode/i);
    assert.doesNotMatch(error.message, /private/);
    return true;
  });
  assert.equal(closed, 1);
});

test('missing browser support and unreadable input produce safe errors', async () => {
  await assert.rejects(createAudioWaveform(audioFile(), { AudioContextClass: null }), /browser|waveform/i);
  await assert.rejects(createAudioWaveform(null), /audio|file/i);
  const unreadable = { async arrayBuffer() { throw new Error('private file path'); } };
  await assert.rejects(createAudioWaveform(unreadable, { AudioContextClass: class {} }), error => {
    assert.doesNotMatch(error.message, /private/);
    return true;
  });
});

test('abort before starting or during file reading avoids opening the decoder', async () => {
  const before = new AbortController();
  before.abort();
  class Unused { constructor() { assert.fail('cancelled work must not open a decoder'); } }
  await assert.rejects(createAudioWaveform(audioFile(), { signal: before.signal, AudioContextClass: Unused }), { name: 'AbortError' });
  const during = new AbortController();
  const file = { async arrayBuffer() { during.abort(); return new ArrayBuffer(0); } };
  await assert.rejects(createAudioWaveform(file, { signal: during.signal, AudioContextClass: Unused }), { name: 'AbortError' });
});

test('abort during a pending decode rejects promptly and closes its temporary context', async () => {
  const controller = new AbortController();
  let beginDecode;
  const started = new Promise(resolve => { beginDecode = resolve; });
  let finishDecode;
  let closed = 0;
  class Decoder {
    decodeAudioData() { beginDecode(); return new Promise(resolve => { finishDecode = resolve; }); }
    async close() { closed++; }
  }
  const pending = createAudioWaveform(audioFile(), { signal: controller.signal, AudioContextClass: Decoder });
  await started;
  controller.abort();
  await assert.rejects(pending, { name: 'AbortError' });
  assert.equal(closed, 1);
  finishDecode(buffer([[1]]));
});
