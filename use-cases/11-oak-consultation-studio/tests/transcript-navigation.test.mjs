import test from 'node:test';
import assert from 'node:assert/strict';
import { revealTranscriptAtTime } from '../public/transcript-navigation.js';

const sample = { utterances: [
  { id: 'one', words: [{ text: 'Hello', start: 1, end: 2 }] },
  { id: 'two', words: [{ text: 'مرحبا', start: 30, end: 31 }] },
] };

function viewport({ nested = true, missing = false } = {}) {
  const panelScrolls = [];
  const pageScrolls = [];
  const word = {
    dataset: { turnId: 'two', word: '0' },
    getBoundingClientRect: () => ({ top: 900, bottom: 922 }),
    scrollIntoView: options => pageScrolls.push(options),
    focus: () => assert.fail('Seeking must not steal keyboard focus'),
  };
  const container = {
    ownerDocument: { defaultView: { innerHeight: 1080 } },
    scrollTop: 100, scrollHeight: 1400, clientHeight: nested ? 500 : 1400, clientTop: 0,
    querySelectorAll: () => missing ? [] : [word],
    getBoundingClientRect: () => ({ top: 300 }),
    scrollTo: options => panelScrolls.push(options),
  };
  return { container, word, panelScrolls, pageScrolls };
}

test('a seek reveals its word inside the desktop transcript without moving the page or focus', () => {
  const h = viewport();
  assert.equal(revealTranscriptAtTime(h.container, sample, 30.5), h.word);
  assert.deepEqual(h.panelScrolls, [{ top: 676, behavior: 'instant' }]);
  assert.deepEqual(h.pageScrolls, []);
});

test('a seek scrolls an expanded mobile transcript vertically into view without animation', () => {
  const h = viewport({ nested: false });
  assert.equal(revealTranscriptAtTime(h.container, sample, 30), h.word);
  assert.deepEqual(h.panelScrolls, []);
  assert.deepEqual(h.pageScrolls, [{ block: 'center', inline: 'nearest', behavior: 'instant' }]);
});

test('a desktop seek also reveals the word when the transcript is below the visible page', () => {
  const h = viewport();
  h.container.ownerDocument.defaultView.innerHeight = 720;
  revealTranscriptAtTime(h.container, sample, 30);
  assert.equal(h.panelScrolls.length, 1);
  assert.deepEqual(h.pageScrolls, [{ block: 'nearest', inline: 'nearest', behavior: 'instant' }]);
});

test('seeking into silence reveals the next spoken word and trailing silence reveals the final word', () => {
  const h = viewport();
  assert.equal(revealTranscriptAtTime(h.container, sample, 15), h.word);
  assert.equal(revealTranscriptAtTime(h.container, sample, 40), h.word);
  assert.equal(h.panelScrolls.length, 2);
});

test('a target excluded by filters leaves both transcript and page untouched', () => {
  const h = viewport({ missing: true });
  assert.equal(revealTranscriptAtTime(h.container, sample, 30.5), null);
  assert.deepEqual(h.panelScrolls, []);
  assert.deepEqual(h.pageScrolls, []);
});

test('empty transcripts and invalid times leave the reading position untouched', () => {
  const h = viewport();
  assert.equal(revealTranscriptAtTime(h.container, { utterances: [] }, 1), null);
  assert.equal(revealTranscriptAtTime(h.container, sample, NaN), null);
  assert.equal(revealTranscriptAtTime(null, sample, 30), null);
  assert.deepEqual(h.panelScrolls, []);
  assert.deepEqual(h.pageScrolls, []);
});

test('backward and end-of-transcript seeks clamp the transcript to its scroll boundaries', () => {
  const h = viewport();
  h.word.getBoundingClientRect = () => ({ top: -200 });
  revealTranscriptAtTime(h.container, sample, 30);
  h.word.getBoundingClientRect = () => ({ top: 2000 });
  revealTranscriptAtTime(h.container, sample, 31);
  assert.deepEqual(h.panelScrolls.map(scroll => scroll.top), [0, 900]);
});
