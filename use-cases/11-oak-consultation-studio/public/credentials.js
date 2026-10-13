export const API_KEY_STORAGE = 'speechmatics.oak.apiKey';

function validateKey(value) {
  const key = typeof value === 'string' ? value.trim() : '';
  if (!key) throw new Error('Enter an API key.');
  if (key.length > 8192 || /\s|[\x00-\x1f\x7f]/u.test(key)) throw new Error('Paste the API key only, without spaces or line breaks.');
  return key;
}

// A user-provided key persists in this browser until explicitly cleared.
// Environment credentials are never stored here or returned by the runtime API.
export function createCredentialStore(storage) {
  if (arguments.length === 0) {
    try { storage = globalThis.localStorage; } catch { storage = null; }
  }
  let apiKey = '';
  let storageAvailable = true;
  function refresh() {
    try {
      const value = storage.getItem(API_KEY_STORAGE);
      storageAvailable = true;
      try { apiKey = value ? validateKey(value) : ''; } catch { apiKey = ''; }
    } catch { apiKey = ''; storageAvailable = false; }
  }
  refresh();
  return {
    status: () => ({ hasKey: Boolean(apiKey), storageAvailable }),
    refresh,
    save(value) {
      const key = validateKey(value);
      try { storage.setItem(API_KEY_STORAGE, key); }
      catch { throw new Error('Browser storage is unavailable. Allow site storage to save your key.'); }
      apiKey = key;
      storageAvailable = true;
    },
    clear() {
      try { storage.removeItem(API_KEY_STORAGE); }
      catch { throw new Error('Browser storage is unavailable. The saved key could not be cleared.'); }
      apiKey = '';
      storageAvailable = true;
    },
    // For the same-origin token request only. Never use this in UI copy or logs.
    forRequest: () => ({ key: apiKey }),
  };
}

export async function readRuntimeConfig(fetcher = globalThis.fetch) {
  const response = await fetcher('./api/config', {
    method: 'GET', cache: 'no-store', credentials: 'omit', redirect: 'error',
    headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error('Configuration unavailable.');
  const data = await response.json();
  if (typeof data?.environment_key_configured !== 'boolean' || typeof data?.transcription_available !== 'boolean') {
    throw new Error('Configuration unavailable.');
  }
  return { environmentKeyConfigured: data.environment_key_configured, transcriptionAvailable: data.transcription_available };
}
