import test from 'node:test';
import assert from 'node:assert/strict';
import { createCredentialStore, readRuntimeConfig } from '../public/credentials.js';

function memoryStorage() {
  const entries = new Map();
  return { getItem: key => entries.get(key) ?? null, setItem: (key, value) => entries.set(key, value), removeItem: key => entries.delete(key) };
}

test('a saved key survives a fresh page instance without appearing in status', () => {
  const storage = memoryStorage();
  const store = createCredentialStore(storage);
  store.save('  fictional-test-key  ');
  assert.equal(store.status().hasKey, true);
  assert.equal(JSON.stringify(store.status()).includes('fictional-test-key'), false);
  assert.deepEqual(createCredentialStore(storage).forRequest(), { key: 'fictional-test-key' });
  store.clear();
  assert.deepEqual(createCredentialStore(storage).forRequest(), { key: '' });
});

test('missing or removed browser keys leave the server to resolve its default automatically', () => {
  const storage = memoryStorage();
  const store = createCredentialStore(storage);
  assert.deepEqual(store.forRequest(), { key: '' });
  store.save('fictional-test-key');
  createCredentialStore(storage).clear();
  store.refresh();
  assert.deepEqual(store.forRequest(), { key: '' });
});

test('invalid credentials do not replace a saved key or disclose their value', () => {
  const store = createCredentialStore(memoryStorage());
  store.save('first-fictional-key');
  for (const key of ['', '  ', 'a\nb', 'a b', 'x'.repeat(8193)]) {
    assert.throws(() => store.save(key));
    assert.equal(store.forRequest().key, 'first-fictional-key');
  }
});

test('blocked browser storage reports a safe error instead of claiming a key was saved', () => {
  const store = createCredentialStore({ getItem() { throw new Error('blocked'); }, setItem() { throw new Error('blocked'); }, removeItem() { throw new Error('blocked'); } });
  assert.equal(store.status().hasKey, false);
  assert.throws(() => store.save('fictional-test-key'), /Browser storage is unavailable/);
  assert.deepEqual(store.forRequest(), { key: '' });
});

test('runtime configuration is fetched without credentials and only allowlisted booleans are retained', async () => {
  let request;
  const config = await readRuntimeConfig(async (url, options) => {
    request = { url, options };
    return { ok: true, json: async () => ({ environment_key_configured: true, transcription_available: false, api_key: 'must-not-be-retained' }) };
  });
  assert.equal(request.url, './api/config');
  assert.equal(request.options.credentials, 'omit');
  assert.equal(request.options.cache, 'no-store');
  assert.equal(request.options.redirect, 'error');
  assert.equal(request.options.body, undefined);
  assert.deepEqual(config, { environmentKeyConfigured: true, transcriptionAvailable: false });
});

test('missing and malformed runtime endpoints fail without retaining response data', async () => {
  for (const response of [
    { ok: false },
    { ok: true, json: async () => ({ environment_key_configured: 'true', transcription_available: false }) },
    { ok: true, json: async () => null },
  ]) {
    await assert.rejects(readRuntimeConfig(async () => response), /Configuration unavailable/);
  }
});
