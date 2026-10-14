import test from 'node:test';
import assert from 'node:assert/strict';
import { revealTranscriptAtTime } from '../public/transcript-navigation.js';
import * as navigation from '../public/transcript-navigation.js';

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

function playbackViewport({ panelTop = 100, panelHeight = 400, initialScroll = 100,
  wordTop = 300, viewportHeight = 800 } = {}) {
  const panelScrolls = [];
  const pageScrolls = [];
  const playButton = {};
  let pageOffset = 0;
  const document = {
    activeElement: playButton,
    defaultView: {
      innerHeight: viewportHeight,
      scrollBy(options) { pageScrolls.push(options); pageOffset += options.top; },
    },
  };
  const word = {
    getBoundingClientRect() {
      const top = wordTop - (container.scrollTop - initialScroll) - pageOffset;
      return { top, bottom: top + 22 };
    },
    focus() { document.activeElement = word; },
  };
  const container = {
    ownerDocument: document,
    scrollTop: initialScroll, scrollHeight: 1400, clientHeight: panelHeight, clientTop: 2,
    contains: element => element === word,
    getBoundingClientRect: () => ({ top: panelTop - pageOffset }),
    scrollTo(options) { panelScrolls.push(options); container.scrollTop = options.top; },
  };
  return { container, word, panelScrolls, pageScrolls, document, playButton };
}

test('playback leaves an already visible word and keyboard focus in place', () => {
  assert.equal(typeof navigation.followTranscriptWord, 'function');
  for (const panelHeight of [400, 1400]) {
    const h = playbackViewport({ panelHeight });
    assert.equal(navigation.followTranscriptWord(h.container, h.word), h.word);
    assert.deepEqual(h.panelScrolls, []);
    assert.deepEqual(h.pageScrolls, []);
    assert.equal(h.document.activeElement, h.playButton);
  }
});

test('playback reveals a word below the panel with the smallest padded scroll', () => {
  const h = playbackViewport({ wordTop: 700 });
  navigation.followTranscriptWord(h.container, h.word);
  assert.deepEqual(h.panelScrolls, [{ top: 344, behavior: 'instant' }]);
  assert.deepEqual(h.word.getBoundingClientRect(), { top: 456, bottom: 478 });
  assert.deepEqual(h.pageScrolls, []);
  assert.equal(h.document.activeElement, h.playButton);
  navigation.followTranscriptWord(h.container, h.word);
  assert.equal(h.panelScrolls.length, 1, 'A revealed word must not keep moving');
});

test('playback reveals a word above the panel without moving the page', () => {
  const h = playbackViewport({ wordTop: 30 });
  navigation.followTranscriptWord(h.container, h.word);
  assert.deepEqual(h.panelScrolls, [{ top: 4, behavior: 'instant' }]);
  assert.deepEqual(h.word.getBoundingClientRect(), { top: 126, bottom: 148 });
  assert.deepEqual(h.pageScrolls, []);
});

test('playback clamps nested scrolling at both transcript boundaries', () => {
  for (const [initialScroll, wordTop, expected] of [[10, 110, 0], [990, 470, 1000]]) {
    const h = playbackViewport({ initialScroll, wordTop });
    navigation.followTranscriptWord(h.container, h.word);
    assert.deepEqual(h.panelScrolls, [{ top: expected, behavior: 'instant' }]);
    assert.equal(h.container.scrollTop, expected);
    assert.deepEqual(h.pageScrolls, []);
  }
});

test('playback moves the page when a word is inside a partially offscreen panel', () => {
  for (const [panelTop, wordTop, delta, top, bottom] of [
    [650, 900, 146, 754, 776],
    [-250, -100, -124, 24, 46],
  ]) {
    const h = playbackViewport({ panelTop, wordTop });
    navigation.followTranscriptWord(h.container, h.word);
    assert.deepEqual(h.panelScrolls, []);
    assert.deepEqual(h.pageScrolls, [{ top: delta, left: 0, behavior: 'instant' }]);
    assert.deepEqual(h.word.getBoundingClientRect(), { top, bottom });
    assert.equal(h.document.activeElement, h.playButton);
  }
});

test('playback remeasures the word after nested scrolling before revealing it on the page', () => {
  const h = playbackViewport({ panelTop: 650, wordTop: 1250 });
  navigation.followTranscriptWord(h.container, h.word);
  assert.deepEqual(h.panelScrolls, [{ top: 344, behavior: 'instant' }]);
  assert.deepEqual(h.pageScrolls, [{ top: 252, left: 0, behavior: 'instant' }]);
  assert.deepEqual(h.word.getBoundingClientRect(), { top: 754, bottom: 776 });
});

test('playback scrolls only the document for an expanded mobile transcript', () => {
  const h = playbackViewport({ panelHeight: 1400, wordTop: 1100 });
  navigation.followTranscriptWord(h.container, h.word);
  assert.deepEqual(h.panelScrolls, []);
  assert.deepEqual(h.pageScrolls, [{ top: 346, left: 0, behavior: 'instant' }]);
  assert.deepEqual(h.word.getBoundingClientRect(), { top: 754, bottom: 776 });
  assert.equal(h.document.activeElement, h.playButton);
});

test('playback ignores missing or filtered-out words without scrolling', () => {
  const h = playbackViewport({ wordTop: 700 });
  assert.equal(navigation.followTranscriptWord(null, h.word), null);
  assert.equal(navigation.followTranscriptWord(h.container, null), null);
  assert.equal(navigation.followTranscriptWord(h.container, {}), null);
  assert.deepEqual(h.panelScrolls, []);
  assert.deepEqual(h.pageScrolls, []);
});
