import test from 'node:test';
import assert from 'node:assert/strict';
import { encodePcm16Wav, prepareAudioFile, MAX_AUDIO_BYTES } from '../public/audio-convert.js';

function buffer(channels = [[-1, 0, 1]], sampleRate = 48000) {
  return { length: channels[0].length, numberOfChannels: channels.length, sampleRate, getChannelData: channel => Float32Array.from(channels[channel]) };
}

test('encodes a PCM16 WAV with correct RIFF headers and clipped samples', () => {
  const result = encodePcm16Wav(buffer([[-2, -0.5, 0, 0.5, 2, NaN]]));
  const bytes = new Uint8Array(result), view = new DataView(result);
  assert.equal(new TextDecoder().decode(bytes.slice(0, 4)), 'RIFF');
  assert.equal(new TextDecoder().decode(bytes.slice(8, 12)), 'WAVE');
  assert.equal(view.getUint32(4, true), result.byteLength - 8);
  assert.equal(view.getUint16(20, true), 1);
  assert.equal(view.getUint16(22, true), 1);
  assert.equal(view.getUint32(24, true), 48000);
  assert.equal(view.getUint32(28, true), 96000);
  assert.equal(view.getUint16(32, true), 2);
  assert.equal(view.getUint16(34, true), 16);
  assert.equal(view.getUint32(40, true), 12);
  assert.deepEqual(Array.from({ length: 6 }, (_, index) => view.getInt16(44 + index * 2, true)), [-32768, -16384, 0, 16384, 32767, 0]);
});

test('preserves stereo sample rate and interleaves left and right channels in frame order', () => {
  const result = encodePcm16Wav(buffer([[-1, 0.5], [1, -0.5]], 44100));
  const view = new DataView(result);
  assert.equal(view.getUint16(22, true), 2);
  assert.equal(view.getUint32(24, true), 44100);
  assert.equal(view.getUint32(28, true), 176400);
  assert.equal(view.getUint16(32, true), 4);
  assert.deepEqual([44, 46, 48, 50].map(offset => view.getInt16(offset, true)), [-32768, 32767, 16384, -16384]);
});

test('checks output size before reading or allocating channel samples', () => {
  const huge = { length: MAX_AUDIO_BYTES, numberOfChannels: 2, sampleRate: 48000, getChannelData: () => assert.fail('must fail before reading samples') };
  assert.throws(() => encodePcm16Wav(huge), /100 MiB|too large/i);
  assert.throws(() => encodePcm16Wav(buffer(), { maxBytes: 44 }), /large|limit/i);
  assert.throws(() => encodePcm16Wav({ ...buffer(), numberOfChannels: 0 }), /invalid|channel/i);
  assert.throws(() => encodePcm16Wav({ ...buffer(), sampleRate: NaN }), /invalid|rate/i);
});

test('leaves supported non-WebM files unchanged without creating AudioContext', async () => {
  const original = new File(['audio'], 'speech.wav', { type: 'audio/wav' });
  class Unused { constructor() { assert.fail('must not decode other formats'); } }
  assert.equal(await prepareAudioFile(original, { AudioContextClass: Unused }), original);
});

test('converts WebM from extension or MIME, closes its decoder, and returns a WAV File', async () => {
  let closed = 0;
  class Decoder {
    async decodeAudioData(data) { assert.ok(data instanceof ArrayBuffer); return buffer([[0.1, 0.2], [0.3, 0.4]], 44100); }
    async close() { closed++; }
  }
  for (const [name, type] of [['recording.WEBM', ''], ['recording', 'audio/webm;codecs=opus']]) {
    const result = await prepareAudioFile(new File(['webm'], name, { type }), { AudioContextClass: Decoder });
    assert.ok(result instanceof File);
    assert.equal(result.name, 'recording.wav');
    assert.equal(result.type, 'audio/wav');
    const view = new DataView(await result.arrayBuffer());
    assert.equal(view.getUint16(22, true), 2);
    assert.equal(view.getUint32(24, true), 44100);
  }
  assert.equal(closed, 2);
});

test('returns an actionable safe decode error and closes the context on failure', async () => {
  let closed = false;
  class Decoder {
    async decodeAudioData() { throw new Error('private internal device detail'); }
    async close() { closed = true; }
  }
  await assert.rejects(prepareAudioFile(new File(['bad'], 'speech.webm'), { AudioContextClass: Decoder }), error => {
    assert.match(error.message, /WebM.*WAV|WAV.*WebM/);
    assert.doesNotMatch(error.message, /private internal/);
    return true;
  });
  assert.equal(closed, true);
  await assert.rejects(prepareAudioFile(new File(['audio'], 'speech.webm'), { AudioContextClass: null }), /browser|WAV/i);
});

test('checks abort before decoding and after asynchronous decoding, always closing the context', async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(prepareAudioFile(new File(['audio'], 'speech.webm'), { signal: controller.signal }), { name: 'AbortError' });
  const during = new AbortController();
  let closed = false;
  class Decoder {
    async decodeAudioData() { during.abort(); return buffer(); }
    async close() { closed = true; }
  }
  await assert.rejects(prepareAudioFile(new File(['audio'], 'speech.webm'), { signal: during.signal, AudioContextClass: Decoder }), { name: 'AbortError' });
  assert.equal(closed, true);
});

test('rejects oversized conversions and closes the context even when encoding fails', async () => {
  let closed = false;
  class Decoder {
    async decodeAudioData() { return buffer(Array.from({ length: 2 }, () => Array(10).fill(0))); }
    async close() { closed = true; }
  }
  await assert.rejects(prepareAudioFile(new File(['data'], 'speech.webm'), { AudioContextClass: Decoder, maxBytes: 50 }), /large|limit/i);
  assert.equal(closed, true);
});
