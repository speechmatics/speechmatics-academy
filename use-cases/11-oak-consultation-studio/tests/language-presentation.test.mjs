import test from 'node:test';
import assert from 'node:assert/strict';
import {
  normalizeLanguageCode, getLanguagePresentation, createLanguagePalette, getWaveformLanguage,
} from '../public/language-presentation.js';
import { SAMPLES } from '../public/demo-data.js';

const benchmarkLanguages = ['en', 'ar', 'da', 'nl', 'fi', 'fr', 'de', 'no', 'pl', 'es', 'sv', 'ru', 'lv'];

function luminance(hex) {
  const [red, green, blue] = hex.slice(1).match(/../gu).map(channel => {
    const value = parseInt(channel, 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

function contrast(first, second) {
  const values = [luminance(first), luminance(second)].sort((a, b) => b - a);
  return (values[0] + 0.05) / (values[1] + 0.05);
}

function colorDistance(first, second) {
  const channels = color => color.slice(1).match(/../gu).map(channel => parseInt(channel, 16));
  const firstChannels = channels(first);
  const secondChannels = channels(second);
  return Math.hypot(...firstChannels.map((channel, index) => channel - secondChannels[index]));
}

test('gives Russian and Latvian distinct accents and readable names', () => {
  const russian = getLanguagePresentation('ru');
  const latvian = getLanguagePresentation('lv');
  assert.equal(russian.name, 'Russian');
  assert.equal(latvian.name, 'Latvian');
  assert.notEqual(russian.color, latvian.color);
  assert.notEqual(russian.ink, latvian.ink);
});

test('normalizes region, script, underscore, case, and legacy language aliases', () => {
  for (const [input, expected] of [[' RU_ru ', 'ru'], ['lv-LV', 'lv'], ['zh-Hant-TW', 'zh'], ['EN-us', 'en'], ['iw-IL', 'he']]) {
    assert.equal(normalizeLanguageCode(input), expected);
  }
  assert.deepEqual(getLanguagePresentation('RU_ru'), getLanguagePresentation('ru'));
  const palette = createLanguagePalette(['ru', 'ru-RU', 'LV_lv', 'lv']);
  assert.deepEqual([...palette.keys()], ['lv', 'ru']);
});

test('returns neutral metadata for malformed or unspecified language codes', () => {
  for (const input of [undefined, null, '', ' ', {}, 45, 'en;color:red', '<script>', 'bad code', 'en--US']) {
    assert.equal(normalizeLanguageCode(input), 'und');
    assert.deepEqual(getLanguagePresentation(input), getLanguagePresentation('und'));
  }
  assert.equal(getLanguagePresentation('und').name, 'Unspecified');
  assert.equal(getLanguagePresentation('und').dir, 'ltr');
  assert.notEqual(getLanguagePresentation('und').color, getLanguagePresentation('en').color);
});

test('generates safe deterministic color metadata for languages outside the demo list', () => {
  for (const code of ['da', 'nl', 'de', 'no', 'ja', 'ko', 'zh', 'qaa']) {
    const metadata = getLanguagePresentation(code);
    assert.deepEqual(metadata, getLanguagePresentation(code));
    for (const key of ['color', 'ink', 'soft', 'border']) assert.match(metadata[key], /^#[\da-f]{6}$/iu);
    assert.equal(typeof metadata.name, 'string');
    assert.ok(metadata.name.length > 0);
  }
  assert.notEqual(getLanguagePresentation('qaa').color, getLanguagePresentation('und').color);
});

test('recognizes common right-to-left languages including regional forms', () => {
  for (const code of ['ar', 'he', 'fa-IR', 'ur', 'ps', 'sd', 'yi', 'ug', 'dv', 'ckb']) {
    assert.equal(getLanguagePresentation(code).dir, 'rtl', code);
  }
  for (const code of ['en', 'ru', 'lv', 'ja', 'und']) assert.equal(getLanguagePresentation(code).dir, 'ltr', code);
});

test('retains the established demo accents when their language combinations do not collide', () => {
  const expected = { en: '#F76B15', es: '#29A383', ar: '#0D3C48', fr: '#FFC53D', fi: '#29A383', sv: '#0D3C48', pl: '#FFC53D' };
  for (const sample of SAMPLES) {
    const palette = createLanguagePalette(sample.languages);
    for (const language of sample.languages) assert.equal(palette.get(language).color, expected[language]);
  }
});

test('assigns unique accents across all benchmark languages plus Russian and Latvian', () => {
  const palette = createLanguagePalette(benchmarkLanguages);
  assert.equal(palette.size, 13);
  assert.equal(new Set([...palette.values()].map(metadata => metadata.color.toLowerCase())).size, 13);
  for (const code of ['en', 'es', 'ar', 'fr']) {
    assert.equal(palette.get(code).color, getLanguagePresentation(code).color);
  }
});

test('separates Danish and German when their preferred generated hues are almost identical', () => {
  const palette = createLanguagePalette(['da', 'de']);
  assert.ok(colorDistance(palette.get('da').color, palette.get('de').color) >= 60);
});

test('keeps generated benchmark accents separated from every co-occurring language', () => {
  const palette = createLanguagePalette(benchmarkLanguages);
  for (const code of ['da', 'de', 'fi', 'nl', 'no', 'pl', 'sv']) {
    for (const [otherCode, metadata] of palette) {
      if (code !== otherCode) assert.ok(colorDistance(palette.get(code).color, metadata.color) >= 60, `${code} is too close to ${otherCode}`);
    }
  }
});

test('resolves accent collisions without depending on input order or duplicate regional codes', () => {
  const original = benchmarkLanguages.slice();
  const forward = createLanguagePalette(original);
  const backward = createLanguagePalette([...original].reverse().concat(['ru-RU', 'EN_us']));
  assert.deepEqual([...forward], [...backward]);
  assert.deepEqual(original, benchmarkLanguages);
  assert.deepEqual([...createLanguagePalette([])], []);
});

test('provides accessible text contrast against white and each pale language surface', () => {
  const palette = createLanguagePalette([...benchmarkLanguages, 'ja', 'ko', 'zh', 'qaa', 'und']);
  for (const [code, metadata] of palette) {
    assert.ok(contrast(metadata.ink, '#FFFFFF') >= 4.5, `${code} ink on white`);
    assert.ok(contrast(metadata.ink, metadata.soft) >= 4.5, `${code} ink on pale surface`);
  }
});

test('carries Russian through inter-word gaps until Latvian begins', () => {
  const words = [
    { start: 1, end: 1.5, language: 'ru-RU' },
    { start: 2, end: 2.5, language: 'ru' },
    { start: 4, end: 5, language: 'lv-LV' },
  ];
  for (const [time, expected] of [[0, null], [0.999, null], [1, 'ru'], [1.5, 'ru'], [2.5, 'ru'], [3.999, 'ru'], [4, 'lv'], [4.999, 'lv'], [5, null], [6, null]]) {
    assert.equal(getWaveformLanguage(words, time), expected, `at ${time}s`);
  }
});

test('uses the most recently started word for overlapping speech', () => {
  const words = [
    { start: 1, end: 4, language: 'ru' },
    { start: 2, end: 5, language: 'lv' },
  ];
  assert.equal(getWaveformLanguage(words, 1.9), 'ru');
  assert.equal(getWaveformLanguage(words, 2), 'lv');
  assert.equal(getWaveformLanguage(words, 4.5), 'lv');
});

test('keeps overlapping speech colored until the final audible word ends', () => {
  const words = [
    { start: 1, end: 5, language: 'ru' },
    { start: 2, end: 3, language: 'lv' },
  ];
  assert.equal(getWaveformLanguage(words, 4.5), 'lv');
  assert.equal(getWaveformLanguage(words, 5), null);
});

test('keeps absent language metadata unspecified and empty timelines neutral', () => {
  assert.equal(getWaveformLanguage([{ start: 1, end: 2 }], 1.5), 'und');
  assert.equal(getWaveformLanguage([], 1), null);
  for (const time of [NaN, Infinity, -Infinity]) {
    assert.equal(getWaveformLanguage([{ start: 1, end: 2, language: 'ru' }], time), null);
  }
});
