import test from 'node:test';
import assert from 'node:assert/strict';
import {
  formatTime, getWords, getStats, filterUtterances,
  findWordAtTime, joinWords, toPlainText, createRequestConfig,
} from '../public/transcript.js';
import { LANGUAGES, SAMPLES } from '../public/demo-data.js';
import * as transcript from '../public/transcript.js';

const sample = {
  isDemo: true,
  speakerNames: { S1: 'Doctor', S2: 'Patient' },
  utterances: [
    { id: 'u1', speaker: 'S1', start: 0, end: 3, words: [
      { text: 'Hello,', language: 'en', start: 0, end: 1 },
      { text: 'glucose', language: 'en', start: 1, end: 2 },
      { text: 'revisión.', language: 'es', start: 2, end: 3 },
    ] },
    { id: 'u2', speaker: 'S2', start: 5, end: 7, words: [
      { text: 'Gracias.', language: 'es', start: 5, end: 6 },
      { text: '<script>alert(1)</script>', language: 'en', start: 6, end: 7 },
    ] },
  ],
};

test('formats a floored elapsed time and handles invalid input', () => {
  for (const [input, expected] of [[0, '00:00'], [82.9, '01:22'], [3601, '60:01'], [-4, '00:00'], [NaN, '00:00'], [Infinity, '00:00']]) {
    assert.equal(formatTime(input), expected);
  }
});

test('flattens word metadata without changing the source', () => {
  const words = getWords(sample);
  assert.equal(words.length, 5);
  assert.deepEqual(words[1], { text: 'glucose', language: 'en', start: 1, end: 2, speaker: 'S1', utteranceId: 'u1' });
  words[1].text = 'Changed';
  assert.equal(sample.utterances[0].words[1].text, 'glucose');
});

test('counts language switches in transcript order including turn boundaries', () => {
  assert.deepEqual(getStats(sample), {
    wordCount: 5, speakerCount: 2, languageCount: 2, switchCount: 2,
    languageCounts: { en: 3, es: 2 },
  });
});

test('intersects query and language on the same word while retaining turn context', () => {
  assert.deepEqual(filterUtterances(sample, { query: 'glucose', language: 'es' }), []);
  assert.deepEqual(filterUtterances(sample, { query: ' GRACIAS ', speaker: 'S1' }), []);
  const result = filterUtterances(sample, { query: 'REVISIÓN', language: 'es', speaker: 'S1' });
  assert.equal(result.length, 1);
  assert.equal(result[0].words.length, 3);
  assert.deepEqual(result[0].matchingWordIndexes, [2]);
  result[0].words[0].text = 'Changed';
  assert.equal(sample.utterances[0].words[0].text, 'Hello,');
  assert.equal(filterUtterances(sample).length, 2);
});

test('finds adjacent phrases without case or diacritic differences and intersects language within each match', () => {
  const result = filterUtterances(sample, { query: ' GLUCOSE   REVISION ', language: 'es' });
  assert.equal(result.length, 1);
  assert.deepEqual(result[0].matchingWordIndexes, [1, 2]);
  assert.equal(filterUtterances(sample, { query: 'glucose revision', language: 'ar' }).length, 0);
  assert.equal(filterUtterances(sample, { query: 'revision gracias' }).length, 0);
  assert.deepEqual(filterUtterances(sample, { query: 'hello glucose' })[0].matchingWordIndexes, [0, 1]);
  const repeated = { utterances: [{ id: 'r', speaker: 'S1', words: [
    { text: 'blood', language: 'en' }, { text: 'test', language: 'en' },
    { text: 'blood', language: 'en' }, { text: 'test', language: 'es' },
  ] }] };
  assert.deepEqual(filterUtterances(repeated, { query: 'blood test', language: 'es' })[0].matchingWordIndexes, [2, 3]);
});

test('uses half-open word intervals and leaves playback gaps empty', () => {
  assert.equal(findWordAtTime(sample, 0).text, 'Hello,');
  assert.equal(findWordAtTime(sample, 1).text, 'glucose');
  assert.equal(findWordAtTime(sample, 2.5).utteranceId, 'u1');
  for (const seconds of [-1, 3, 4.5, 7, NaN, Infinity]) {
    assert.equal(findWordAtTime(sample, seconds), null);
  }
});

test('seek navigation reveals speech at boundaries and on either side of silence', () => {
  assert.equal(typeof transcript.findWordForSeek, 'function');
  const leadingSilence = { utterances: sample.utterances.slice(1) };
  assert.equal(transcript.findWordForSeek(leadingSilence, 0).text, 'Gracias.');
  for (const [seconds, expected] of [[0, 'Hello,'], [1, 'glucose'], [2.5, 'revisión.'], [3, 'Gracias.'], [4.5, 'Gracias.'], [5, 'Gracias.'], [7, '<script>alert(1)</script>'], [90, '<script>alert(1)</script>']]) {
    assert.equal(transcript.findWordForSeek(sample, seconds).text, expected);
  }
  const result = transcript.findWordForSeek(sample, 4);
  assert.equal(result.utteranceId, 'u2');
  assert.equal(result.speaker, 'S2');
  result.text = 'Changed';
  assert.equal(sample.utterances[1].words[0].text, 'Gracias.');
  assert.equal(findWordAtTime(sample, 4), null);
  assert.equal(findWordAtTime(sample, 7), null);
});

test('seek navigation resolves overlapping and unordered turns deterministically', () => {
  assert.equal(typeof transcript.findWordForSeek, 'function');
  const unordered = { utterances: [
    { id: 'later', speaker: 'S2', words: [{ text: 'later', start: 10, end: 11 }] },
    { id: 'long', speaker: 'S1', words: [{ text: 'long', start: 3, end: 14 }] },
    { id: 'early', speaker: 'S1', words: [{ text: 'early', start: 1, end: 2 }] },
    { id: 'tied', speaker: 'S3', words: [{ text: 'tied', start: 1, end: 2 }, { text: 'also long', start: 4, end: 14 }] },
  ] };
  assert.equal(transcript.findWordForSeek(unordered, 0).utteranceId, 'early');
  assert.equal(transcript.findWordForSeek(unordered, 2).utteranceId, 'long');
  assert.deepEqual(transcript.findWordForSeek(unordered, 10.5), findWordAtTime(unordered, 10.5));
  assert.equal(transcript.findWordForSeek(unordered, 11).utteranceId, 'long');
  assert.equal(transcript.findWordForSeek(unordered, 20).utteranceId, 'long');
});

test('seek navigation ignores malformed words and rejects invalid times', () => {
  assert.equal(typeof transcript.findWordForSeek, 'function');
  const malformed = { utterances: [null, {}, { id: 'bad', words: [
    null, {}, { text: 'missing' }, { text: '', start: 0, end: 2 },
    { text: 'negative', start: -1, end: 4 }, { text: 'backward', start: 5, end: 4 },
    { text: 'zero', start: 2, end: 2 }, { text: 'infinite', start: 3, end: Infinity },
    { text: 'not a number', start: NaN, end: 4 }, { text: 'string', start: '1', end: 2 },
  ] }] };
  for (const seconds of [0, 1, 2, 8]) assert.equal(transcript.findWordForSeek(malformed, seconds), null);
  for (const seconds of [-1, NaN, Infinity, -Infinity, '1', undefined, null]) assert.equal(transcript.findWordForSeek(sample, seconds), null);
  for (const empty of [null, {}, { utterances: [] }]) assert.equal(transcript.findWordForSeek(empty, 0), null);
  const mixed = { utterances: [...malformed.utterances, sample.utterances[1]] };
  assert.equal(transcript.findWordForSeek(mixed, 0).text, 'Gracias.');
  assert.equal(transcript.findWordForSeek(mixed, 5.5).text, 'Gracias.');
});

test('joins separated punctuation and Arabic punctuation without extra spaces', () => {
  assert.equal(joinWords(['Hello', ',', '(', 'review', ')', '.'].map(text => ({ text }))), 'Hello, (review).');
  assert.equal(joinWords(['نعم', '،', 'شكرًا', '؟'].map(text => ({ text }))), 'نعم، شكرًا؟');
});

test('exports labeled plain text with speaker names and unmodified user text', () => {
  const text = toPlainText(sample, { S1: 'Dr. Morgan', S2: 'Patient' });
  assert.match(text, /Scripted demonstration.*fictional consultation/);
  assert.match(text, /Synthetic word timings/);
  assert.ok(text.includes('[00:00] Dr. Morgan: Hello, glucose revisión.'));
  assert.ok(text.includes('[00:05] Patient: Gracias. <script>alert(1)</script>'));
});

test('handles missing and malformed transcript entries consistently', () => {
  const malformed = { utterances: [null, {}, { id: 'empty', words: null }, { id: 'u', speaker: 'S1', words: [null, {}, { text: 42 }, { text: '   ' }, { text: 'Valid', language: 'en', start: NaN, end: 1 }] }] };
  assert.deepEqual(getWords(null), []);
  assert.equal(getWords(malformed).length, 1);
  assert.equal(getStats(malformed).wordCount, 1);
  assert.equal(filterUtterances(malformed).length, 1);
  assert.equal(findWordAtTime(malformed, 0), null);
  assert.equal(joinWords([null, {}, { text: 'Fine' }]), 'Fine');
  assert.doesNotThrow(() => toPlainText(null));
});

test('builds an Oak multilingual request without endpoint or unsupported parameters', () => {
  assert.deepEqual(createRequestConfig({ region: 'eu' }), {
    type: 'transcription', transcription_config: { model: 'oak-1', language: 'multi', diarization: 'speaker', output_locale: 'en-GB' },
  });
  const hints = ['en', 'ar'];
  const result = createRequestConfig({ region: 'us', locale: 'en-US', diarization: 'channel', hints });
  assert.deepEqual(result, {
    type: 'transcription', transcription_config: { model: 'oak-1', language: 'multi', diarization: 'channel', output_locale: 'en-US', language_hints: ['en', 'ar'] },
  });
  hints.push('es');
  assert.equal(result.transcription_config.language_hints.length, 2);
  assert.deepEqual(createRequestConfig({ locale: '', diarization: 'channel', hints: ['fi', 'sv'] }), {
    type: 'transcription', transcription_config: {
      model: 'oak-1', language: 'multi', diarization: 'channel', language_hints: ['fi', 'sv'],
    },
  });
});

test('scripted samples support filtering and finite synthetic playback in both speaker modes', () => {
  assert.equal(SAMPLES.length, 4);
  assert.ok(SAMPLES.some(demo => demo.diarization === 'channel'));
  assert.ok(SAMPLES.some(demo => demo.languages.length === 3));
  assert.ok(SAMPLES.some(demo => !demo.languages.includes('en')));
  assert.equal(LANGUAGES.ar.dir, 'rtl');
  for (const demo of SAMPLES) {
    assert.equal(demo.isDemo, true);
    assert.equal(demo.region, 'eu');
    assert.ok(demo.duration > 0);
    const words = getWords(demo);
    assert.deepEqual([...new Set(words.map(word => word.language))].sort(), [...demo.languages].sort());
    assert.ok(words.length > 50);
    let previousEnd = 0;
    for (const word of words) {
      assert.ok(LANGUAGES[word.language]);
      assert.ok(demo.speakerNames[word.speaker]);
      assert.ok(word.start >= previousEnd && word.end > word.start && word.end <= demo.duration);
      assert.equal(findWordAtTime(demo, (word.start + word.end) / 2).text, word.text);
      previousEnd = word.end;
    }
    for (const language of demo.languages) {
      assert.ok(filterUtterances(demo, { language }).length > 0);
    }
  }
});
