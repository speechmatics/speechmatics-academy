import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { HINT_LANGUAGES, LANGUAGE_HINTS_STORAGE, createLanguagePreferences } from '../public/language-preferences.js';

function memoryStorage(value) {
  const values = new Map(value === undefined ? [] : [[LANGUAGE_HINTS_STORAGE, value]]);
  return {
    getItem: key => values.get(key) ?? null,
    setItem: (key, next) => values.set(key, next),
    removeItem: key => values.delete(key),
  };
}

test('the supported hints match the real 56-language Flutter catalog', async () => {
  const source = await readFile(new URL('../../09-flutter-mobile-transcription/flutter/lib/models/lang_catalog.dart', import.meta.url), 'utf8');
  const expected = [...source.matchAll(/LangInfo\('([^']+)', '([^']+)'/g)].map(([, code, name]) => ({ code, name }));
  assert.equal(expected.length, 56);
  assert.deepEqual(HINT_LANGUAGES, expected);
});

test('new browser preferences use automatic detection and persist canonical selections across reloads', () => {
  const storage = memoryStorage();
  const preferences = createLanguagePreferences(storage);
  assert.deepEqual(preferences.get(), []);
  preferences.save(['EN', ' cy ', 'en', 'CMN']);
  assert.deepEqual(preferences.get(), ['en', 'cy', 'cmn']);
  assert.deepEqual(JSON.parse(storage.getItem(LANGUAGE_HINTS_STORAGE)), ['en', 'cy', 'cmn']);
  assert.deepEqual(createLanguagePreferences(storage).get(), ['en', 'cy', 'cmn']);
  preferences.save([]);
  assert.deepEqual(createLanguagePreferences(storage).get(), []);
});

test('get returns a copy so callers cannot change saved preferences', () => {
  const preferences = createLanguagePreferences(memoryStorage('["en"]'));
  preferences.get().push('cy');
  assert.deepEqual(preferences.get(), ['en']);
});

test('refresh normalizes valid stored hints and defaults malformed or unsupported values to automatic', () => {
  const storage = memoryStorage('["EN"," cy ","en"]');
  const preferences = createLanguagePreferences(storage);
  assert.deepEqual(preferences.get(), ['en', 'cy']);
  for (const value of ['{', 'null', '{}', '"en"', '["en",null]', '["en","not-a-language"]']) {
    storage.setItem(LANGUAGE_HINTS_STORAGE, value);
    preferences.refresh();
    assert.deepEqual(preferences.get(), [], value);
  }
  storage.setItem(LANGUAGE_HINTS_STORAGE, '["ja"]');
  preferences.refresh();
  assert.deepEqual(preferences.get(), ['ja']);
  storage.removeItem(LANGUAGE_HINTS_STORAGE);
  preferences.refresh();
  assert.deepEqual(preferences.get(), []);
});

test('invalid saves do not replace the previously saved selection', () => {
  const storage = memoryStorage('["en"]');
  const preferences = createLanguagePreferences(storage);
  for (const value of [null, 'cy', {}, [''], [42], ['en', 'xx']]) {
    assert.throws(() => preferences.save(value), /language/i);
    assert.deepEqual(preferences.get(), ['en']);
    assert.equal(storage.getItem(LANGUAGE_HINTS_STORAGE), '["en"]');
  }
});

test('unavailable reads fall back to automatic and write failures keep the saved selection', () => {
  const unavailable = createLanguagePreferences({ getItem() { throw new Error('blocked'); } });
  assert.deepEqual(unavailable.get(), []);
  assert.throws(() => unavailable.save(['cy']), /storage.*unavailable/i);
  assert.deepEqual(unavailable.get(), []);

  const preferences = createLanguagePreferences({
    getItem: () => '["en"]',
    setItem() { throw new Error('quota'); },
  });
  assert.throws(() => preferences.save(['cy']), /storage.*unavailable/i);
  assert.deepEqual(preferences.get(), ['en']);
});
