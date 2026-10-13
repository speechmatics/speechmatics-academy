import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeBatchTranscript } from '../public/batch-transcript.js';
import { getWords, getStats, filterUtterances, findWordAtTime, toPlainText } from '../public/transcript.js';

// Field locations follow Speechmatics Batch output and diarization documentation.
const word = (content, start_time, end_time, language = 'en', speaker = 'S1', extra = {}) => ({
  type: 'word', start_time, end_time, alternatives: [{ content, language, speaker }], ...extra,
});
const punctuation = (content, time, attaches_to = 'previous', speaker = 'S1', extra = {}) => ({
  type: 'punctuation', start_time: time, end_time: time, attaches_to,
  alternatives: [{ content, speaker }], ...extra,
});

test('normalizes documented multilingual alternatives and real word times without inferred metadata', () => {
  const input = {
    format: '2.9', job: { id: 'job-1', data_name: 'consultation.wav', duration: 2 },
    metadata: { transcription_config: { model: 'oak-1', language: 'multi', diarization: 'speaker', output_locale: 'en-GB' } },
    results: [word('Hello', .2, .52), word('مرحبا', .6, 1.04, 'ar'), punctuation('؟', 1.04, 'previous', 'S1', { is_eos: true })],
    summary: { content: 'Do not present this as a summary.' },
  };
  input.results[0].alternatives[0].confidence = .8;
  input.results[0].alternatives[0].tags = ['medical'];
  const output = normalizeBatchTranscript(input, { region: 'eu' });
  assert.equal(output.isDemo, false);
  assert.equal(output.transcribed, true);
  assert.equal(output.jobId, 'job-1');
  assert.equal(output.title, 'consultation.wav');
  assert.equal(output.duration, 2);
  assert.equal(output.region, 'eu');
  assert.equal(output.locale, 'en-GB');
  assert.deepEqual(output.languages, ['en', 'ar']);
  assert.deepEqual(output.speakerNames, { S1: 'Speaker 1' });
  assert.deepEqual(output.utterances[0].words, [
    { text: 'Hello', language: 'en', start: .2, end: .52 },
    { text: 'مرحبا؟', language: 'ar', start: .6, end: 1.04 },
  ]);
  assert.equal(output.summary, undefined);
  assert.equal(output.utterances[0].words[0].term, undefined);
  assert.equal(output.utterances[0].words[0].confidence, undefined);
  assert.equal(getStats(output).wordCount, 2);
  assert.equal(getStats(output).switchCount, 1);
  assert.equal(filterUtterances(output, { language: 'ar', query: 'مرحبا' }).length, 1);
  assert.equal(findWordAtTime(output, .7).text, 'مرحبا؟');
  assert.match(toPlainText(output), /Hello مرحبا؟/);
  assert.ok(!toPlainText(output).includes('Scripted'));
  assert.equal(input.results[1].alternatives[0].content, 'مرحبا');
});

test('keeps channel attribution separate from speakers and attaches interleaved punctuation to its channel', () => {
  const output = normalizeBatchTranscript({
    metadata: { transcription_config: { diarization: 'channel' } },
    results: [word('Hello', 0, 1, 'en', undefined, { channel: 'Agent' }), word('Cześć', .2, .8, 'pl', undefined, { channel: 'Caller' }), punctuation('.', 1, 'previous', undefined, { channel: 'Agent' })],
  });
  assert.equal(output.diarization, 'channel');
  assert.deepEqual(output.speakerNames, { Agent: 'Agent', Caller: 'Caller' });
  assert.deepEqual(output.utterances.map(turn => [turn.speaker, turn.words[0].text, turn.start, turn.end]), [['Agent', 'Hello.', 0, 1], ['Caller', 'Cześć', .2, .8]]);
});

test('preserves next, previous, both and none punctuation without manufacturing timed words', () => {
  const output = normalizeBatchTranscript({ results: [
    punctuation('(', 0, 'next'), word('follow', 0, .4), punctuation('-', .4, 'both'), word('up', .4, .8),
    punctuation(')', .8), punctuation('—', .8, 'none'), word('review', .8, 1.2), punctuation('.', 1.2),
  ] });
  assert.deepEqual(output.utterances[0].words, [
    { text: '(follow-', language: 'en', start: 0, end: .4 },
    { text: 'up) —', language: 'en', start: .4, end: .8, separatorBefore: '' },
    { text: 'review.', language: 'en', start: .8, end: 1.2 },
  ]);
  assert.equal(getStats(output).wordCount, 3);
});

test('honors reported language delimiters without guessing a known language or direction', () => {
  const output = normalizeBatchTranscript({
    metadata: { language_pack_info: { per_language_word_delimiters: { ja: '' }, per_language_writing_direction: { ja: 'left-to-right' } } },
    results: [word('今日', 0, .5, 'ja'), word('は', .5, .7, 'ja')],
  });
  assert.deepEqual(output.languages, ['ja']);
  assert.equal(output.utterances[0].words[1].separatorBefore, '');
  assert.equal(output.utterances[0].words[1].language, 'ja');
});

test('uses an unattributed identity and und language when labels are absent or unknown', () => {
  const first = word('Unlabelled', 0, .5);
  first.alternatives = [{ content: 'Unlabelled' }];
  const second = word('unknown', .5, 1, undefined, 'UU');
  delete second.alternatives[0].language;
  const output = normalizeBatchTranscript({ results: [first, second, word('bonjour', 1, 1.5, 'fr', 'Custom_Name')] });
  assert.deepEqual(output.languages, ['und', 'fr']);
  assert.deepEqual(output.speakerNames, { UU: 'Unattributed', Custom_Name: 'Custom_Name' });
  assert.equal(output.utterances[0].speaker, 'UU');
  assert.equal(output.utterances[0].words.length, 2);
  assert.equal(getWords(output)[0].language, 'und');
});

test('splits turns on identity, end of sentence, and pauses while preserving overlapping timings', () => {
  const output = normalizeBatchTranscript({ results: [
    word('One', 0, .8), punctuation('.', .8, 'previous', 'S1', { is_eos: true }),
    word('Two', 1, 2), word('Overlap', 1.2, 1.7, 'en', 'S2'), word('Later', 5, 6, 'en', 'S2'),
  ] });
  assert.deepEqual(output.utterances.map(turn => [turn.speaker, turn.start, turn.end]), [['S1', 0, .8], ['S1', 1, 2], ['S2', 1.2, 1.7], ['S2', 5, 6]]);
  assert.deepEqual(getWords(output).map(word => [word.start, word.end]), [[0, .8], [1, 2], [1.2, 1.7], [5, 6]]);
  assert.equal(new Set(output.utterances.map(turn => turn.id)).size, 4);
});

test('sorts out-of-order words stably without flattening overlap or changing their times', () => {
  const output = normalizeBatchTranscript({ results: [word('Later', 3, 4), word('First', 0, 1, 'en', 'S2'), word('Same', 0, .5, 'en', 'S3')] });
  assert.deepEqual(getWords(output).map(word => word.text), ['First', 'Same', 'Later']);
  assert.equal(output.duration, 4);
});

test('handles empty and malformed results without fabricated words or nonfinite playback duration', () => {
  for (const input of [null, {}, { results: null }, { results: 'not an array' }]) {
    assert.throws(() => normalizeBatchTranscript(input), /results.*array/i);
  }
  for (const input of [{ results: [] }, { results: [null, {}, { type: 'audio_event' }, punctuation('.', 0)] }]) {
    const output = normalizeBatchTranscript(input, { duration: Infinity });
    assert.deepEqual(output.utterances, []);
    assert.deepEqual(output.languages, []);
    assert.deepEqual(output.speakerNames, {});
    assert.equal(output.duration, 0);
  }
  const output = normalizeBatchTranscript({ results: [
    word('Negative', -1, 0), word('Reversed', 2, 1), word('Missing', undefined, 1), word('NaN', NaN, 1),
    word('Infinity', 1, Infinity), word('', 0, 1), { ...word('Bad alternative', 0, 1), alternatives: [] },
    { ...word('Only first alternative', 0, 1), alternatives: [null, { content: 'Never selected', language: 'en' }] },
    word('Valid', 2, 2.5), word('Instant', 2.5, 2.5),
  ] });
  assert.deepEqual(getWords(output).map(word => word.text), ['Valid', 'Instant']);
  assert.equal(output.duration, 2.5);
});

test('keeps untrusted attribution labels prototype-safe and rejects invalid language codes', () => {
  const output = normalizeBatchTranscript({ results: [word('First', 0, 1, '__proto__', '__proto__'), word('Second', 1, 2, 'fr', 'constructor')] });
  assert.equal(Object.getPrototypeOf(output.speakerNames), Object.prototype);
  assert.equal(Object.hasOwn(output.speakerNames, '__proto__'), true);
  assert.equal(output.speakerNames.__proto__, '__proto__');
  assert.equal(output.speakerNames.constructor, 'constructor');
  assert.deepEqual(output.languages, ['und', 'fr']);
});

test('uses supplied job context but keeps duration large enough for actual word intervals', () => {
  const output = normalizeBatchTranscript({ job: { id: 'server-id', duration: 2 }, results: [word('<script>alert(1)</script>', 3, 4)] },
    { title: 'Uploaded consultation', duration: 1, region: 'us', locale: 'en-US', diarization: 'speaker', jobId: 'local-job-id' });
  assert.equal(output.title, 'Uploaded consultation');
  assert.equal(output.jobId, 'local-job-id');
  assert.equal(output.region, 'us');
  assert.equal(output.locale, 'en-US');
  assert.equal(output.duration, 4);
  assert.equal(getWords(output)[0].text, '<script>alert(1)</script>');
  assert.ok(toPlainText(output).includes('<script>alert(1)</script>'));
});
